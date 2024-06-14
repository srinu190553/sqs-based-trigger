import boto3
import os
import time

# Initialize SQS and DynamoDB clients/resources
sqs = boto3.client('sqs', region_name='us-east-1')  # Specify the correct region
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')  # Specify the correct region

# Define your SQS queue URL and DynamoDB table name
QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/933085737869/my-sqs-queue"
TABLE_NAME = "my-dynamodb-table"

def process_message(message):
    table = dynamodb.Table(TABLE_NAME)
    table.put_item(Item={'id': message['MessageId'], 'body': message['Body']})

def main():
    while True:
        # try:
        response = sqs.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=20,
        )

        if 'Messages' in response:
            for message in response['Messages']:
                process_message(message)
                # Delete the processed message from the queue
                sqs.delete_message(
                    QueueUrl=QUEUE_URL,
                    ReceiptHandle=message['ReceiptHandle']
                )
        else:
            print("No messages received")

        # except Exception as e:
        #     print(f"Error processing SQS messages: {e}")

        time.sleep(10)

if __name__ == "__main__":
    main()
