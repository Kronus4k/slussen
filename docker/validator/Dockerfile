FROM public.ecr.aws/lambda/python:3.13

COPY pyproject.toml /tmp/build/
COPY src /tmp/build/src
RUN pip install --no-cache-dir /tmp/build && rm -rf /tmp/build

COPY contracts ${LAMBDA_TASK_ROOT}/contracts
COPY lambdas/validator/handler.py ${LAMBDA_TASK_ROOT}/

CMD ["handler.lambda_handler"]