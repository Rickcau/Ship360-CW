import pytest
from app.utils import helpers
from datetime import datetime

def test_format_response():
    data = {"foo": "bar"}
    response = helpers.format_response(data)
    assert response["status"] == "success"
    assert response["data"] == data
    assert isinstance(response["timestamp"], datetime)

def test_format_error():
    message = "Something went wrong"
    code = "ERR001"
    error = helpers.format_error(message, code)
    assert error["status"] == "error"
    assert error["error"]["message"] == message
    assert error["error"]["code"] == code
    assert isinstance(error["timestamp"], datetime)

def test_sanitize_input():
    dirty = "  hello world  "
    clean = helpers.sanitize_input(dirty)
    assert clean == "hello world" 