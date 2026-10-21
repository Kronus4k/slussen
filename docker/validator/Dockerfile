FROM public.ecr.aws/lambda/python:3.13@sha256:d5d5c74e3639a01fac254c9334a60604aa50327aa122b3ec26151e055a06a6a0

COPY requirements.lock /tmp/build/
RUN pip install --no-cache-dir --require-hashes -r /tmp/build/requirements.lock

COPY pyproject.toml /tmp/build/
COPY src /tmp/build/src
RUN pip install --no-cache-dir --no-deps /tmp/build && rm -rf /tmp/build

COPY contracts ${LAMBDA_TASK_ROOT}/contracts
COPY lambdas/validator/handler.py ${LAMBDA_TASK_ROOT}/

CMD ["handler.lambda_handler"]