from pydantic import BaseModel, EmailStr
from datetime import date, datetime
from typing import Optional

# User Schemas
class UserCreate(BaseModel):
    email: EmailStr
    full_name: str
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserResponse(BaseModel):
    id: int
    email: str
    full_name: str
    profile_image: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True

class UserUpdate(BaseModel):
    full_name: str
    profile_image: Optional[str] = None

class PasswordChange(BaseModel):
    current_password: str
    new_password: str

# Token Schema
class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str

class TokenRefresh(BaseModel):
    refresh_token: str

# Category Schema
class CategoryResponse(BaseModel):
    id: int
    name: str
    type: str
    icon: Optional[str]
    color: Optional[str]
    
    class Config:
        from_attributes = True

# Transaction Schemas
class TransactionCreate(BaseModel):
    category_id: int
    amount: float
    description: Optional[str] = None
    transaction_date: datetime

class TransactionResponse(BaseModel):
    id: int
    user_id: int
    category_id: int
    amount: float
    description: Optional[str]
    transaction_date: datetime
    created_at: datetime
    category: CategoryResponse
    
    class Config:
        from_attributes = True

# Stats Schema
class MonthlyStats(BaseModel):
    income: float
    expense: float
    balance: float