FROM public.ecr.aws/docker/library/alpine:3.18.2

RUN apk add --no-cache python3 && \
python3 -m ensurepip && \
pip3 install --upgrade pip

# Update vulnerable packages
RUN apk update && apk upgrade
RUN pip3 install --upgrade setuptools

WORKDIR /app
ADD . /app
RUN pip3 install -r requirements.txt

CMD ["python", "app.py"]
