import json
import boto3
import time

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('PreliminaryOrders')
final_orders_table = dynamodb.Table('ConfirmedOrders')

def lambda_handler(event, context):
    # Parse the request body
    body = json.loads(event['body'])
    
    # Ensure 'order_id' is present in the request body
    if 'order_id' not in body:
        return {
            'statusCode': 400,
            'body': json.dumps('order_id is required in the request.')
        }
    
    order_id = body['order_id']
    received_otp = body['otp']

    # Fetch the item from PreliminaryOrders table using the 'order_id'
    response = table.get_item(Key={'order_id': order_id})
    
    # If the item doesn't exist, return a 404 Not Found response
    if 'Item' not in response:
        return {
            'statusCode': 404,
            'body': json.dumps('Order with the provided order_id not found.')
        }

    item = response['Item']

    # Check if the OTP has expired
    if int(time.time()) > item['otp_expiry']:
        return {
            'statusCode': 400,
            'body': json.dumps('OTP has expired.')
        }

    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
    }

    # If the received OTP matches the OTP in the database
    if received_otp == item['otp']:
        # Move the order to the ConfirmedOrders table
        final_orders_table.put_item(Item=item)

        # Remove the order from the PreliminaryOrders table
        table.delete_item(Key={'order_id': order_id})

        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps('OTP verified successfully!')
        }
    else:
        # If the OTP doesn't match, return an error response
        return {
            'statusCode': 400,
            'headers': headers,
            'body': json.dumps('Incorrect OTP.')
        }
