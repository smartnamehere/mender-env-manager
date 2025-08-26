import boto3
import os
import json
import uuid

dynamodb = boto3.resource('dynamodb')
ec2 = boto3.client('ec2')

def handler(event, context):
    table_name = os.environ['DYNAMODB_TABLE']
    security_group_id = os.environ['SECURITY_GROUP_ID']
    table = dynamodb.Table(table_name)

    env_id = str(uuid.uuid4())

    user_data = """#!/bin/bash
apt-get update
apt-get install -y docker.io docker-compose-plugin
git clone -b v4.0.0 https://github.com/mendersoftware/mender-server.git mender-server
cd mender-server
export MENDER_IMAGE_TAG=v4.0.0
docker compose up -d
MENDER_USERNAME=admin@docker.mender.io
MENDER_PASSWORD=PleaseReplaceWithASecurePassword
docker compose run --name create-user useradm create-user --username \"$MENDER_USERNAME\" --password \"$MENDER_PASSWORD\"
"""

    response = ec2.run_instances(
        ImageId='ami-053b0d53c279acc90', # Ubuntu 20.04 LTS
        InstanceType='t3.micro',
        MinCount=1,
        MaxCount=1,
        SecurityGroupIds=[security_group_id],
        UserData=user_data,
        TagSpecifications=[
            {
                'ResourceType': 'instance',
                'Tags': [
                    {
                        'Key': 'Name',
                        'Value': f'mender-environment-{env_id}'
                    },
                ]
            },
        ]
    )

    instance_id = response['Instances'][0]['InstanceId']

    # Wait for the instance to be running
    waiter = ec2.get_waiter('instance_running')
    waiter.wait(InstanceIds=[instance_id])

    # Get the public IP address
    instance_details = ec2.describe_instances(InstanceIds=[instance_id])
    public_ip = instance_details['Reservations'][0]['Instances'][0]['PublicIpAddress']

    table.put_item(
        Item={
            'id': env_id,
            'instance_id': instance_id,
            'url': f'http://{public_ip}'
        }
    )

    return {
        'statusCode': 201,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'OPTIONS,POST,GET,DELETE'
        },
        'body': json.dumps({'id': env_id, 'url': f'http://{public_ip}'})
    }
