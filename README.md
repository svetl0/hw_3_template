# ДЗ по Docker: приложение со счётчиком

Овечкина Светлана Павловна, БПМИ266. Делала на 8 баллов.

## Что в репозитории

- `app/` - исходники приложения (я их не менял)
- `Dockerfile` - собирает образ приложения из `python:3.13-slim`
- `.dockerignore` - чтобы в образ не попадал лишний мусор
- `compose.yaml` - два сервиса: `app` и `redis`
- `.env.example` - пример настроек
- `logs-level4.txt` - логи с первого этапа (один контейнер)

## Как запустить

```bash
cp .env.example .env
docker compose up -d --build --wait
curl -fsS http://127.0.0.1:8080/
```

Остановить:

```bash
docker compose down
```

`down -v` писать нельзя, он удаляет volume и счётчик пропадёт.

## Настройки

В файле `.env` можно поменять две вещи:

- `GREETING` - приветствие, которое приложение возвращает в ответе (по умолчанию `Hello, Docker!`)
- `HOST_PORT` - порт на компьютере, по умолчанию 8080. Внутри контейнера приложение всегда на 8000.

## Как устроен compose.yaml

В `app` я передаю `STORAGE=redis` и `REDIS_URL=redis://redis:6379/0`. Использую имя сервиса `redis`, а не localhost, потому что внутри контейнера localhost - это сам контейнер приложения.

Порт на компьютер открыт только у приложения. У Redis секции `ports` нет, в `docker compose ps` у него виден только внутренний `6379/tcp`.

Redis запускается с `--appendonly yes`, чтобы данные писались на диск, а папка `/data` лежит в именованном volume `redis-data`.

У обоих сервисов есть healthcheck. У приложения он ходит на `/readyz` через Python (curl в образе нет), у Redis это `redis-cli ping`. Приложение стартует только когда Redis уже healthy (`depends_on` с `service_healthy`).

## Что я проверила (8 баллов)

### Запуск

```
$ docker compose up -d --build --wait
 ✔ Container hw_3_template-redis-1 Healthy
 ✔ Container hw_3_template-app-1   Healthy
$ docker compose ps
NAME                    SERVICE   STATUS                    PORTS
hw_3_template-app-1     app       Up 5 seconds (healthy)    0.0.0.0:8080->8000/tcp, [::]:8080->8000/tcp
hw_3_template-redis-1   redis     Up 10 seconds (healthy)   6379/tcp
$ curl -fsS http://127.0.0.1:8080/
{"greeting": "Привет из Docker Compose!", "count": 0, "hostname": "c71956704c20", "storage": "redis"}
```

### 1. Счётчик после down и up

Сделала три `POST /increment`, значит N = 3:

```
{"greeting": "Привет из Docker Compose!", "count": 1, "hostname": "c71956704c20", "storage": "redis"}
{"greeting": "Привет из Docker Compose!", "count": 2, "hostname": "c71956704c20", "storage": "redis"}
{"greeting": "Привет из Docker Compose!", "count": 3, "hostname": "c71956704c20", "storage": "redis"}
```

Потом пересоздала контейнеры (без `-v`):

```
$ docker compose down
$ docker compose up -d --wait
$ curl -fsS http://127.0.0.1:8080/
{"greeting": "Привет из Docker Compose!", "count": 3, "hostname": "f5855a548906", "storage": "redis"}
```

`hostname` поменялся, значит контейнер новый, а счётчик остался 3.

### 2. Redis остановлен

```
$ docker compose stop redis
$ curl -s -o /dev/null -w "healthz: %{http_code}\n" http://127.0.0.1:8080/healthz
healthz: 200
$ curl -s -o /dev/null -w "readyz: %{http_code}\n" http://127.0.0.1:8080/readyz
readyz: 503
$ curl -s -o /dev/null -w "increment: %{http_code}\n" -X POST http://127.0.0.1:8080/increment
increment: 503
```

Приложение продолжает работать (`/healthz` отвечает 200), а `/readyz` и `POST /increment` дают 503, потому что хранилища нет.

### 3. Redis запущен обратно

Приложение я не перезапускала:

```
$ docker compose start redis
$ sleep 10
$ curl -fsS http://127.0.0.1:8080/
{"greeting": "Привет из Docker Compose!", "count": 3, "hostname": "f5855a548906", "storage": "redis"}
$ curl -fsS -X POST http://127.0.0.1:8080/increment
{"greeting": "Привет из Docker Compose!", "count": 4, "hostname": "f5855a548906", "storage": "redis"}
$ docker compose ps
NAME                    SERVICE   STATUS                    PORTS
hw_3_template-app-1     app       Up 57 seconds (healthy)   0.0.0.0:8080->8000/tcp, [::]:8080->8000/tcp
hw_3_template-redis-1   redis     Up 10 seconds (healthy)   6379/tcp
```

`GET /` снова вернул 3, следующий POST дал 4 (N + 1). Что приложение не перезапускали, видно по тому, что `hostname` тот же и оно работает дольше Redis.

## Что было на прошлых этапах (там ещё был SQLite)

Это я делала до перехода на Redis, сейчас в `compose.yaml` другая конфигурация.

**4 балла, один контейнер.** Собрала образ и запустила так:

```bash
docker build -t counter-app .
docker run -d --name counter -p 8080:8000 -e GREETING="Hello from my container" counter-app
```

Приветствие дошло до приложения, счётчик увеличивался 0 -> 1 -> 2. Логи лежат в `logs-level4.txt`.

**6 баллов, Compose и volume.** Порт и приветствие менялись через `.env` (пробовала `HOST_PORT=9090` и `GREETING="Привет!"`, приложение ответило на порту 9090 с новым приветствием). Счётчик 3 сохранился после `docker compose down` и `up -d` благодаря именованному volume `counter-data`, а следующий POST дал 4.
