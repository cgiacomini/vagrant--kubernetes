FROM python:3.9-alpine

WORKDIR /app
COPY ./example-001.py .

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --upgrade pip
RUN pip install prometheus_client

EXPOSE 8001
EXPOSE 8000
ENTRYPOINT ["python", "example-001.py"]
