.PHONY: setup migrate run worker beat demo clean

setup:
	cp -n .env.example .env || true
	pip install -r requirements.txt
	docker-compose up -d
	sleep 3
	python manage.py migrate
	python manage.py create_demo

migrate:
	python manage.py makemigrations
	python manage.py migrate

run:
	python manage.py runserver 0.0.0.0:8000

worker:
	celery -A config worker -l info

beat:
	celery -A config beat -l info --scheduler django_celery_beat.schedulers:DatabaseScheduler

demo:
	python manage.py create_demo

clean:
	docker-compose down -v
