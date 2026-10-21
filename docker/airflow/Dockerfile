FROM apache/airflow:3.3.2-python3.13@sha256:e9982ad3f49a60418622e1baf80c34b0daf3fa5091a336cb5ee61f0cdd189371

USER root

COPY requirements.lock /tmp/build/
RUN python -m venv /opt/slussen-venv \
 && /opt/slussen-venv/bin/pip install --no-cache-dir --require-hashes -r /tmp/build/requirements.lock

COPY pyproject.toml /tmp/build/
COPY src /tmp/build/src
RUN /opt/slussen-venv/bin/pip install --no-cache-dir --no-deps /tmp/build && rm -rf /tmp/build

COPY contracts /opt/slussen/contracts

USER airflow