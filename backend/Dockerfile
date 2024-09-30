# tiangolo/uvicorn-gunicorn-fastapi 사용시 Gunicorn 이 80번 포트를 자동으로 할당?
FROM --platform=linux/amd64 tiangolo/uvicorn-gunicorn-fastapi:python3.10 

WORKDIR /app/

# Install Poetry
RUN curl -sSL https://install.python-poetry.org | POETRY_HOME=/opt/poetry python && \
    cd /usr/local/bin && \
    ln -s /opt/poetry/bin/poetry && \
    poetry config virtualenvs.create false

# Copy poetry.lock* in case it doesn't exist in the repo
COPY ./pyproject.toml ./poetry.lock* /app/

# Allow installing dev dependencies to run tests
ARG INSTALL_DEV=false
RUN bash -c "if [ $INSTALL_DEV == 'true' ] ; then poetry install --no-root ; else poetry install --no-root --only main ; fi"

ENV PYTHONPATH=/app

COPY ./app /app/app
COPY ./app/scripts /app/app/scripts

# Ensure the entrypoint script is executable
RUN chmod +x /start.sh

# Set the default command to run the application
CMD ["/start.sh"]