FROM python:3.9-slim

WORKDIR /app

# Copy requirements before rest of source code for better caching
COPY backend/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY backend/app.py .
COPY frontend/ ./frontend/

# Expose backend on port 3000
EXPOSE 3000

# Run the Flask app
CMD ["python", "app.py"]
