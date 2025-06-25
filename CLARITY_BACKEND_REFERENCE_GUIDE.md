# CLARITY Backend Reference Guide

## Overview

The `BACKEND_REFERENCE/clarity-loop-backend/` directory contains a complete copy of the CLARITY backend codebase for reference during frontend development. This is **NOT** the active backend - it's a snapshot for development reference only.

**Live Backend URL**: https://clarity.novamindnyc.com/api/v1/docs

## Purpose

This backend reference serves several critical purposes:

1. **API Contract Reference**: View exact endpoint implementations and data models
2. **DTO Verification**: Ensure frontend DTOs match backend expectations
3. **Business Logic Understanding**: See how backend processes health data
4. **Integration Testing**: Understand expected request/response formats
5. **Error Handling**: See what errors backend might return

## What's Included

### ✅ Kept for Reference
- **Python source code** (`app/` directory with all endpoints)
- **Database models** (`app/models/`)
- **API routes** (`app/api/v1/`)
- **Services and business logic** (`app/services/`)
- **Configuration examples** (`.env.example`, `pyproject.toml`)
- **AWS configurations** (`ops/` directory)
- **OpenAPI specifications** (`openapi.json`, `openapi.yaml`)
- **Research models** (`research/` directory with PAT models)
- **Docker configuration** (`Dockerfile`, `docker-compose.yml`)

### ❌ Removed for Safety/Clarity
- Git history and linkages (`.git/`, `.github/`)
- Development tool configs (`.roomodes`, `.windsurfrules`, etc.)
- Cache directories (`__pycache__/`, `.pytest_cache/`, etc.)
- Node modules and build artifacts
- Most markdown documentation (to avoid confusion with frontend docs)
- Log files and coverage reports

## Security Considerations

The backend reference has been sanitized:
- No actual `.env` files (only `.env.example`)
- No private keys or certificates
- No database dumps or sensitive data
- Comprehensive `.gitignore` to prevent accidental commits

## How to Use This Reference

### 1. Finding Endpoint Implementations

```bash
# Example: Find user authentication endpoints
grep -r "login" BACKEND_REFERENCE/clarity-loop-backend/app/api/

# Find specific endpoint
grep -r "POST.*users" BACKEND_REFERENCE/clarity-loop-backend/app/api/v1/
```

### 2. Understanding Data Models

Check `BACKEND_REFERENCE/clarity-loop-backend/app/models/` for:
- SQLAlchemy models
- Pydantic schemas
- Data validation rules

### 3. Verifying DTOs

Compare your frontend DTOs with backend schemas:
```python
# Backend schema example (from backend reference)
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    first_name: str
    last_name: str
    date_of_birth: date
```

### 4. API Documentation

The OpenAPI specs provide complete API documentation:
- `BACKEND_REFERENCE/clarity-loop-backend/openapi.json`
- `BACKEND_REFERENCE/clarity-loop-backend/openapi.yaml`

## Important Notes

1. **This is a REFERENCE only** - Do not run or deploy from this directory
2. **Version may be outdated** - Always verify against live API
3. **No modifications** - Don't edit backend code here; it won't affect the live system
4. **Security first** - Never add real credentials or secrets to this directory

## Quick Command Reference

```bash
# Search for an endpoint
find BACKEND_REFERENCE -name "*.py" -exec grep -l "endpoint_name" {} \;

# View model definitions
cat BACKEND_REFERENCE/clarity-loop-backend/app/models/user.py

# Check API route structure
ls -la BACKEND_REFERENCE/clarity-loop-backend/app/api/v1/endpoints/

# View OpenAPI spec
cat BACKEND_REFERENCE/clarity-loop-backend/openapi.json | jq '.paths'
```

## When to Reference

Use the backend reference when:
- Implementing new API integrations
- Debugging request/response issues  
- Understanding business logic requirements
- Verifying data model structures
- Checking error response formats

## Updating the Reference

If the backend reference becomes outdated:
1. Get a fresh copy from the actual backend repository
2. Remove git linkages: `rm -rf .git .github`
3. Clean up as per this guide
4. Verify no secrets are included

Remember: The live API at https://clarity.novamindnyc.com is the source of truth!