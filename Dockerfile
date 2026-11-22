FROM python:3.13-slim

WORKDIR /srv

COPY app/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./

ENV PORT=8000

EXPOSE 8000

CMD ["python", "app.py"]
