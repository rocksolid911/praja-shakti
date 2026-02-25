import json
import logging

import boto3
from django.conf import settings

logger = logging.getLogger(__name__)


def get_bedrock_client():
    kwargs = {'region_name': settings.AWS_REGION}
    if settings.AWS_ACCESS_KEY_ID:
        kwargs['aws_access_key_id'] = settings.AWS_ACCESS_KEY_ID
        kwargs['aws_secret_access_key'] = settings.AWS_SECRET_ACCESS_KEY
    return boto3.client('bedrock-runtime', **kwargs)


def call_bedrock_claude(prompt: str, max_tokens: int = 1000, system: str = '') -> str:
    """Call AWS Bedrock Claude and return the text response."""
    try:
        client = get_bedrock_client()
        body = {
            'anthropic_version': 'bedrock-2023-05-31',
            'max_tokens': max_tokens,
            'messages': [{'role': 'user', 'content': prompt}],
        }
        if system:
            body['system'] = system

        response = client.invoke_model(
            modelId=settings.BEDROCK_MODEL_ID,
            body=json.dumps(body),
        )
        result = json.loads(response['body'].read())
        return result['content'][0]['text']
    except Exception as e:
        logger.error(f"Bedrock Claude call failed: {e}")
        raise


def get_embedding(text: str) -> list[float]:
    """Get text embedding from Amazon Titan."""
    try:
        client = get_bedrock_client()
        response = client.invoke_model(
            modelId=settings.BEDROCK_EMBEDDING_MODEL_ID,
            body=json.dumps({'inputText': text}),
        )
        result = json.loads(response['body'].read())
        return result['embedding']
    except Exception as e:
        logger.error(f"Bedrock embedding call failed: {e}")
        raise
