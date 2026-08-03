FROM public.ecr.aws/docker/library/python:3.12-slim-bookworm

RUN useradd --create-home --uid 10001 appuser && \
    install -d -o appuser -g appuser /app

WORKDIR /app

COPY requirements.txt .
RUN python -m pip install --no-cache-dir --upgrade pip && \
    python -m pip install --no-cache-dir -r requirements.txt

COPY task.py .

USER appuser

CMD ["python", "task.py"]
