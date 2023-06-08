FROM python:3.9-alpine

WORKDIR /app
COPY ./sms-sender.py .

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --upgrade pip
RUN pip install prometheus_client

EXPOSE 9088
EXPOSE 9089
ENTRYPOINT ["python", "sms-sender.py"]
