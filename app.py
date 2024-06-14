import boto3
import os
import time

sqs = boto3.client('sqs')
dynamodb = boto3.resource('dynamodb')

QUEUE_URL = os.getenv('SQS_QUEUE_URL')
TABLE_NAME = os.getenv('DYNAMODB_TABLE_NAME')

def process_message(message):
    table = dynamodb.Table(TABLE_NAME)
    table.put_item(Item={'id': message['MessageId'], 'body': message['Body']})

def main():
    while True:
        response = sqs.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=20,
        )

        if 'Messages' in response:
            for message in response['Messages']:
                process_message(message)
                sqs.delete_message(
                    QueueUrl=QUEUE_URL,
                    ReceiptHandle=message['ReceiptHandle']
                )
        else:
            print("No messages received")

        time.sleep(10)

if __name__ == "__main__":
    main()
