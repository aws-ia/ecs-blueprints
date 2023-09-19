FROM public.ecr.aws/docker/library/alpine:latest

RUN apk add --no-cache python3 && \
python3 -m ensurepip && \
pip3 install --upgrade pip

WORKDIR /app
ADD . /app
RUN pip3 install -r requirements.txt

CMD ["python", "app.py"]
