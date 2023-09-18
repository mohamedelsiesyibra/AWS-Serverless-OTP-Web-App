import json
import boto3
import random
import time
import uuid

dynamodb = boto3.resource('dynamodb')
sns_client = boto3.client('sns')
table = dynamodb.Table('PreliminaryOrders')  # Adjust the name if different

def generate_otp():
    """Generate a 6-digit OTP"""
    return str(random.randint(100000, 999999))

def store_to_dynamodb(data, otp):
    otp_ttl = int(time.time()) + 300  # OTP expires in 5 minutes (300 seconds)
    order_id = str(uuid.uuid4())  # Generate a unique order ID
    item = {
        'order_id': order_id,
        'phone': data['phone'],
        'name': data['name'],
        'address': data['address'],
        'details': data['details'],
        'services': data.get('services', []),
        'otp': otp,
        'otp_expiry': otp_ttl
    }
    table.put_item(Item=item)
    return order_id  # Return the generated order_id

def lambda_handler(event, context):
    # Extract the form data from the event object
    body = json.loads(event['body'])
    
    # Store form data to DynamoDB with OTP and get order_id
    otp = generate_otp()
    order_id = store_to_dynamodb(body, otp)
    

    # Send OTP
    message = f"Your OTP is: {otp}"
    sns_client.publish(
        PhoneNumber=body['phone'],
        Message=message
    )


    # Note: Set the Access-Control-Allow-Origin header value 
    # to your specific domain in production for better security.
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
    }

    return {
        'statusCode': 200,
        'headers': headers,
        'body': json.dumps({
            'message': 'Form submitted successfully and OTP sent!',
            'order_id': order_id
        })
    }
