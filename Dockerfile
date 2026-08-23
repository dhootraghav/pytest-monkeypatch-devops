FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    SETUPTOOLS_SCM_PRETEND_VERSION_FOR_PYTEST=9.2.0

WORKDIR /app

RUN addgroup --system pytest && adduser --system --ingroup pytest pytest

COPY --chown=pytest:pytest . /app
RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir -e .

USER pytest

# pytest is a test framework, not a network service: this image intentionally
# exposes no port or HTTP health check. Its successful test exit status is its health signal.
CMD ["python", "-m", "pytest", "testing/test_monkeypatch.py", "-q"]
