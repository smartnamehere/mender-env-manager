import boto3
import os
import json

dynamodb = boto3.resource('dynamodb')
ec2 = boto3.client('ec2')

def handler(event, context):
    table_name = os.environ['DYNAMODB_TABLE']
    table = dynamodb.Table(table_name)

    env_id = event['pathParameters']['id']

    # Get the item from DynamoDB to get the instance_id
    response = table.get_item(Key={'id': env_id})
    item = response.get('Item')

    if not item:
        return {
            'statusCode': 404,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST,GET,DELETE'
            },
            'body': json.dumps({'error': 'Environment not found'})
        }

    instance_id = item.get('instance_id')

    # Terminate the EC2 instance
    if instance_id and instance_id != 'i-placeholder123':
        try:
            ec2.terminate_instances(InstanceIds=[instance_id])
        except ec2.exceptions.ClientError as e:
            # Handle cases where the instance is already terminated
            if e.response['Error']['Code'] != 'InvalidInstanceID.NotFound':
                raise e

    # Delete the item from DynamoDB
    table.delete_item(Key={'id': env_id})

    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'OPTIONS,POST,GET,DELETE'
        },
        'body': json.dumps({'message': 'Environment taken down successfully'})
    }
