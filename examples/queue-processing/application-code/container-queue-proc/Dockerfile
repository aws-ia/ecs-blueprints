FROM public.ecr.aws/docker/library/python:alpine3.16

WORKDIR /app

COPY ./src /app

RUN pip install -r requirements.txt

ENTRYPOINT python app.py
