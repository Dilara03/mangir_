from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import func, extract
from sqlalchemy.orm import joinedload
from datetime import datetime, date, timedelta
from typing import List
import models
import schemas
import random
import auth
from secrets import token_urlsafe
from database import engine, get_db

# Tabloları oluştur
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Mangır API", version="1.0.0")


# CORS (Flutter'dan erişim için)
origins = [
    "http://localhost",
    "http://localhost:8000",
    "http://127.0.0.1:8000",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Root endpoint
@app.get("/")
def read_root():
    return {"message": "Mangır API - Çalışıyor!", "version": "1.0.0"}

# ============================================
# AUTH ENDPOINTS
# ============================================

@app.post("/api/auth/register", response_model=schemas.UserResponse, status_code=status.HTTP_201_CREATED)
def register(user: schemas.UserCreate, db: Session = Depends(get_db)):
    """Yeni kullanıcı kaydı"""
    # Email kontrolü
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if db_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bu email zaten kayıtlı"
        )
    
    # Şifreyi hashle
    hashed_password = auth.get_password_hash(user.password)
    
    # Yeni kullanıcı oluştur
    new_user = models.User(
        email=user.email,
        full_name=user.full_name,
        password_hash=hashed_password
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return new_user

@app.post("/api/auth/login", response_model=schemas.Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """Kullanıcı girişi - Access ve Refresh token döner"""
    # Kullanıcıyı bul
    user = db.query(models.User).filter(models.User.email == form_data.username).first()
    
    if not user or not auth.verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email veya şifre hatalı",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Access ve Refresh token oluştur
    access_token = auth.create_access_token(data={"sub": user.email})
    refresh_token = auth.create_refresh_token(data={"sub": user.email})
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer"
    }

@app.post("/api/auth/refresh", response_model=schemas.Token)
def refresh_token(
    token_data: schemas.TokenRefresh,
    db: Session = Depends(get_db)
):
    """Refresh token ile yeni access token al"""
    # Refresh token'ı doğrula
    user = auth.verify_refresh_token(token_data.refresh_token, db)
    
    # Yeni tokenlar oluştur
    new_access_token = auth.create_access_token(data={"sub": user.email})
    new_refresh_token = auth.create_refresh_token(data={"sub": user.email})
    
    return {
        "access_token": new_access_token,
        "refresh_token": new_refresh_token,
        "token_type": "bearer"
    }

@app.get("/api/auth/me", response_model=schemas.UserResponse)
def get_current_user_info(current_user: models.User = Depends(auth.get_current_user)):
    """Mevcut kullanıcı bilgilerini getir"""
    return current_user

@app.put("/api/auth/profile", response_model=schemas.UserResponse)
def update_profile(
    user_update: schemas.UserUpdate,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    """Kullanıcı profil bilgilerini güncelle"""
    current_user.full_name = user_update.full_name
    if user_update.profile_image: current_user.profile_image = user_update.profile_image
    db.commit()
    db.refresh(current_user)
    return current_user

@app.put("/api/auth/change-password")
def change_password(
    password_data: schemas.PasswordChange,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    """Kullanıcı şifresini değiştir"""
    # Mevcut şifreyi doğrula
    if not auth.verify_password(password_data.current_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mevcut şifre hatalı"
        )
    
    # Yeni şifreyi hashle ve kaydet
    current_user.password_hash = auth.get_password_hash(password_data.new_password)
    db.commit()
    
    return {"message": "Şifre başarıyla değiştirildi"}

password_reset_tokens = {}

@app.post("/api/auth/forgot-password")
def forgot_password(email: str, db: Session = Depends(get_db)):
    """Şifre sıfırlama token'ı oluştur"""
    user = db.query(models.User).filter(models.User.email == email).first()
    
    if not user:
        # Güvenlik için her zaman başarılı mesaj dön
        return {"message": "Eğer bu email kayıtlıysa, sıfırlama linki gönderildi"}
    
    # Token oluştur (6 haneli kod)
    reset_code = str(random.randint(100000, 999999))
    password_reset_tokens[email] = {
        "code": reset_code,
        "expires": datetime.utcnow() + timedelta(minutes=15)
    }
    
    # Email gönderme (şimdilik console'a yazdır)
    print(f"Şifre sıfırlama kodu: {reset_code}")
    
    return {"message": "Sıfırlama kodu gönderildi"}

@app.post("/api/auth/reset-password")
def reset_password(
    email: str,
    reset_code: str,
    new_password: str,
    db: Session = Depends(get_db)
):
    """Şifreyi sıfırla"""
    # Token kontrolü
    if email not in password_reset_tokens:
        raise HTTPException(status_code=400, detail="Geçersiz veya süresi dolmuş kod")
    
    token_data = password_reset_tokens[email]
    
    if token_data["expires"] < datetime.utcnow():
        del password_reset_tokens[email]
        raise HTTPException(status_code=400, detail="Kod süresi dolmuş")
    
    if token_data["code"] != reset_code:
        raise HTTPException(status_code=400, detail="Hatalı kod")
    
    # Kullanıcıyı bul ve şifreyi değiştir
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")
    
    user.password_hash = auth.get_password_hash(new_password)
    db.commit()
    
    # Token'ı sil
    del password_reset_tokens[email]
    
    return {"message": "Şifre başarıyla sıfırlandı"}

# ============================================
# CATEGORY ENDPOINTS
# ============================================

@app.get("/api/categories", response_model=List[schemas.CategoryResponse])
def get_categories(db: Session = Depends(get_db)):
    """Tüm kategorileri getir"""
    categories = db.query(models.Category).all()
    return categories

@app.post("/api/categories/seed")
def seed_categories(db: Session = Depends(get_db)):
    """Varsayılan kategorileri ekle (ilk kurulum için)"""
    # Zaten var mı kontrol et
    existing = db.query(models.Category).first()
    if existing:
        return {"message": "Kategoriler zaten mevcut"}
    
    default_categories = [
        {"name": "Maaş", "type": models.TransactionType.income, "icon": "💰", "color": "#4CAF50"},
        {"name": "Yemek", "type": models.TransactionType.expense, "icon": "🍔", "color": "#FF5722"},
        {"name": "Ulaşım", "type": models.TransactionType.expense, "icon": "🚗", "color": "#2196F3"},
        {"name": "Eğlence", "type": models.TransactionType.expense, "icon": "🎮", "color": "#9C27B0"},
        {"name": "Faturalar", "type": models.TransactionType.expense, "icon": "💡", "color": "#FF9800"},
        {"name": "Sağlık", "type": models.TransactionType.expense, "icon": "🏥", "color": "#E91E63"},
        {"name": "Alışveriş", "type": models.TransactionType.expense, "icon": "🛒", "color": "#00BCD4"},
        {"name": "Kira", "type": models.TransactionType.expense, "icon": "🏠", "color": "#795548"},
        {"name": "Diğer Gelir", "type": models.TransactionType.income, "icon": "💵", "color": "#8BC34A"},
        {"name": "Diğer Gider", "type": models.TransactionType.expense, "icon": "📦", "color": "#607D8B"},
    ]
    
    for cat_data in default_categories:
        category = models.Category(**cat_data)
        db.add(category)
    
    db.commit()
    return {"message": "Kategoriler başarıyla eklendi", "count": len(default_categories)}

# ============================================
# TRANSACTION ENDPOINTS
# ============================================

@app.post("/api/transactions", response_model=schemas.TransactionResponse, status_code=status.HTTP_201_CREATED)
def create_transaction(
    transaction: schemas.TransactionCreate,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    """Yeni işlem ekle"""
    # Kategori var mı kontrol et
    category = db.query(models.Category).filter(models.Category.id == transaction.category_id).first()
    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kategori bulunamadı"
        )
    
    new_transaction = models.Transaction(
        user_id=current_user.id,
        category_id=transaction.category_id,
        amount=transaction.amount,
        description=transaction.description,
        transaction_date=transaction.transaction_date
    )
    
    db.add(new_transaction)
    db.commit()
    db.refresh(new_transaction)
    
    return new_transaction

@app.get("/api/transactions", response_model=List[schemas.TransactionResponse])
def get_transactions(
    skip: int = 0,
    limit: int = 100,
    year: int = None,
    month: int = None,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    """Kullanıcının tüm işlemlerini getir"""
    query = db.query(models.Transaction).options(
        joinedload(models.Transaction.category)
    ).filter(
        models.Transaction.user_id == current_user.id
    )
    
    # Ay filtresi varsa ekle
    if year and month:
        query = query.filter(
            extract('year', models.Transaction.transaction_date) == year,
            extract('month', models.Transaction.transaction_date) == month
        )
    
    transactions = query.order_by(
        models.Transaction.transaction_date.desc()
    ).offset(skip).limit(limit).all()
    
    return transactions

@app.get("/api/transactions/{transaction_id}", response_model=schemas.TransactionResponse)
def get_transaction(
    transaction_id: int,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    """Tek bir işlemi getir"""
    transaction = db.query(models.Transaction).filter(
        models.Transaction.id == transaction_id,
        models.Transaction.user_id == current_user.id
    ).first()
    
    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="İşlem bulunamadı"
        )
    
    return transaction

@app.put("/api/transactions/{transaction_id}", response_model=schemas.TransactionResponse)
def update_transaction(
    transaction_id: int,
    transaction_update: schemas.TransactionCreate,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    """İşlemi güncelle"""
    transaction = db.query(models.Transaction).filter(
        models.Transaction.id == transaction_id,
        models.Transaction.user_id == current_user.id
    ).first()
    
    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="İşlem bulunamadı"
        )
    
    transaction.category_id = transaction_update.category_id
    transaction.amount = transaction_update.amount
    transaction.description = transaction_update.description
    transaction.transaction_date = transaction_update.transaction_date
    
    db.commit()
    db.refresh(transaction)
    
    return transaction

@app.delete("/api/transactions/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_transaction(
    transaction_id: int,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    """İşlemi sil"""
    transaction = db.query(models.Transaction).filter(
        models.Transaction.id == transaction_id,
        models.Transaction.user_id == current_user.id
    ).first()
    
    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="İşlem bulunamadı"
        )
    
    db.delete(transaction)
    db.commit()
    
    return None

# ============================================
# STATISTICS ENDPOINTS
# ============================================

@app.get("/api/stats/period", response_model=schemas.MonthlyStats)
def get_period_stats(
    period: str = "monthly",  # weekly, monthly, yearly
    year: int = None,
    month: int = None,
    week_start: str = None,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    """Dönemsel istatistikler (haftalık, aylık, yıllık)"""
    today = date.today()
    
    if period == "weekly":
        # Takvimsel hafta
        if week_start:
            start_date = datetime.strptime(week_start, '%Y-%m-%d').date()
        else:
            today_weekday = today.weekday()
            start_date = today - timedelta(days=today_weekday)
        
        end_date = start_date + timedelta(days=6)
        
        start_datetime = datetime.combine(start_date, datetime.min.time())
        end_datetime = datetime.combine(end_date, datetime.max.time())

        income = db.query(func.sum(models.Transaction.amount)).join(
            models.Category
        ).filter(
            models.Transaction.user_id == current_user.id,
            models.Category.type == models.TransactionType.income,
            models.Transaction.transaction_date >= start_datetime,  
            models.Transaction.transaction_date <= end_datetime      
        ).scalar() or 0.0
        
        expense = db.query(func.sum(models.Transaction.amount)).join(
            models.Category
        ).filter(
            models.Transaction.user_id == current_user.id,
            models.Category.type == models.TransactionType.expense,
            models.Transaction.transaction_date >= start_datetime,  
            models.Transaction.transaction_date <= end_datetime      
        ).scalar() or 0.0
        
    elif period == "yearly":
        # Yıllık
        if not year:
            year = today.year
        
        income = db.query(func.sum(models.Transaction.amount)).join(
            models.Category
        ).filter(
            models.Transaction.user_id == current_user.id,
            models.Category.type == models.TransactionType.income,
            extract('year', models.Transaction.transaction_date) == year
        ).scalar() or 0.0
        
        expense = db.query(func.sum(models.Transaction.amount)).join(
            models.Category
        ).filter(
            models.Transaction.user_id == current_user.id,
            models.Category.type == models.TransactionType.expense,
            extract('year', models.Transaction.transaction_date) == year
        ).scalar() or 0.0
        
    else:  # monthly (varsayılan)
        if not year or not month:
            year = today.year
            month = today.month
        
        income = db.query(func.sum(models.Transaction.amount)).join(
            models.Category
        ).filter(
            models.Transaction.user_id == current_user.id,
            models.Category.type == models.TransactionType.income,
            extract('year', models.Transaction.transaction_date) == year,
            extract('month', models.Transaction.transaction_date) == month
        ).scalar() or 0.0
        
        expense = db.query(func.sum(models.Transaction.amount)).join(
            models.Category
        ).filter(
            models.Transaction.user_id == current_user.id,
            models.Category.type == models.TransactionType.expense,
            extract('year', models.Transaction.transaction_date) == year,
            extract('month', models.Transaction.transaction_date) == month
        ).scalar() or 0.0
    
    balance = income - expense
    
    return {
        "income": float(income),
        "expense": float(expense),
        "balance": float(balance)
    }


@app.get("/api/stats/by-category-period")
def get_stats_by_category_period(
    period: str = "monthly",
    year: int = None,
    month: int = None,
    week_start: str = None,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    """Dönemsel kategori istatistikleri"""
    today = date.today()
    
    query = db.query(
        models.Category.id,
        models.Category.name,
        models.Category.icon,
        models.Category.color,
        func.sum(models.Transaction.amount).label('total')
    ).join(
        models.Transaction
    ).filter(
        models.Transaction.user_id == current_user.id
    )
    
    if period == "weekly":
        # Takvimsel hafta
        if week_start:
            start_date = datetime.strptime(week_start, '%Y-%m-%d').date()
        else:
            today_weekday = today.weekday()
            start_date = today - timedelta(days=today_weekday)
        
        end_date = start_date + timedelta(days=6)
        
        
        start_datetime = datetime.combine(start_date, datetime.min.time())
        end_datetime = datetime.combine(end_date, datetime.max.time())
        
        query = query.filter(
            models.Transaction.transaction_date >= start_datetime,  
            models.Transaction.transaction_date <= end_datetime      
        )
    elif period == "yearly":
        if not year:
            year = today.year
        query = query.filter(
            extract('year', models.Transaction.transaction_date) == year
        )
    else:  # monthly
        if not year or not month:
            year = today.year
            month = today.month
        query = query.filter(
            extract('year', models.Transaction.transaction_date) == year,
            extract('month', models.Transaction.transaction_date) == month
        )
    
    results = query.group_by(models.Category.id).all()
    
    total_amount = sum([r.total for r in results])
    
    category_stats = []
    for r in results:
        percentage = (r.total / total_amount * 100) if total_amount > 0 else 0
        category_stats.append({
            "category_id": r.id,
            "category_name": r.name,
            "icon": r.icon,
            "color": r.color,
            "total": float(r.total),
            "percentage": round(percentage, 2)
        })
    
    return category_stats

# ============================================
# HEALTH CHECK
# ============================================

@app.get("/health")
def health_check():
    """API sağlık kontrolü"""
    return {"status": "healthy", "timestamp": datetime.utcnow()}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)