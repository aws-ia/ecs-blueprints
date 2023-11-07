FROM python:3.9
WORKDIR /app
COPY requirements.txt ./requirements.txt
RUN pip3 install -r requirements.txt
COPY . .
EXPOSE 80
CMD streamlit run web_app.py \
    --server.headless true \
    --browser.serverAddress="0.0.0.0" \
    --server.enableCORS true \
    --browser.gatherUsageStats false \
    --server.port 80
