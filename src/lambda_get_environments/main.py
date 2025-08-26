import boto3
import os
import json

dynamodb = boto3.resource('dynamodb')

def handler(event, context):
    table_name = os.environ['DYNAMODB_TABLE']
    table = dynamodb.Table(table_name)

    result = table.scan()

    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'OPTIONS,POST,GET,DELETE',
            'X-Debug-Header': 'hello'
        },
        'body': json.dumps(result['Items'])
    }
