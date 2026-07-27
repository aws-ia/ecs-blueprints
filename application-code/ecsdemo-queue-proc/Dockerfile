FROM public.ecr.aws/docker/library/python:3.12-alpine3.21

RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup && \
    mkdir -p /tmp/ecsproc && \
    chown appuser:appgroup /tmp/ecsproc

WORKDIR /app

COPY ./src/requirements.txt .
RUN python -m pip install --no-cache-dir --prefer-binary -r requirements.txt

COPY --chown=appuser:appgroup ./src /app

USER appuser

ENTRYPOINT ["python", "app.py"]
