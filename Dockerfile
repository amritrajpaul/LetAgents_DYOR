FROM python:3.10-slim
WORKDIR /app
COPY backend /app/backend
RUN pip install --no-cache-dir -r backend/requirements.txt
EXPOSE 8000
ENTRYPOINT ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
