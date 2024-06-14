# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install the dependencies
RUN pip install boto3

# Make port 80 available to the world outside this container
EXPOSE 80

# Define environment variables
ENV SQS_QUEUE_URL=
ENV DYNAMODB_TABLE_NAME=

# Run app.py when the container launches
CMD ["python", "app.py"]
