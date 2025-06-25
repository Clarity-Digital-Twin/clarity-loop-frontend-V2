# Backend Reference Directory

This directory contains a sanitized copy of the CLARITY backend for frontend development reference.

## What's Here

- **Complete backend source code** in `clarity-loop-backend/src/clarity/`
- **API endpoint implementations** in `src/clarity/api/v1/`
- **Data models and schemas** in `src/clarity/models/`
- **OpenAPI specifications** for API documentation
- **AWS configurations** in `ops/` directory
- **Docker configuration** for understanding deployment

## What's Been Removed

- Git history (`.git/`, `.github/`)
- Development tool configs that could conflict
- Cache directories and logs
- Node modules and Python caches
- Most markdown docs (to avoid confusion)

## Security

- No actual environment files (only `.env.example`)
- No private keys or certificates
- Comprehensive `.gitignore` to prevent accidents

## Usage

See `CLARITY_BACKEND_REFERENCE_GUIDE.md` in the project root for detailed usage instructions.

**Remember**: This is a REFERENCE only. The live backend is at https://clarity.novamindnyc.com