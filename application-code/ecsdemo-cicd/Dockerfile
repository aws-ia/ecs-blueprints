FROM public.ecr.aws/docker/library/alpine:latest

RUN apk add --no-cache python3 py3-pip && \
python3 -m venv /path/to/venv

ENV PATH="/path/to/venv/bin:$PATH"

WORKDIR /app
ADD . /app

RUN pip3 install -r requirements.txt

CMD ["python3", "app.py"]