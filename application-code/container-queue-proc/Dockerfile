# See: https://gallery.ecr.aws/docker/library/python
FROM public.ecr.aws/docker/library/python:3.9.19-alpine3.20

RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup

COPY ./src /app

WORKDIR /app

RUN pip install --no-cache-dir --prefer-binary -r requirements.txt

USER appuser

RUN mkdir -p /tmp/ecsproc

ENTRYPOINT ["python", "app.py"]
