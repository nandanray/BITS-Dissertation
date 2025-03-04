FROM python:3.10-slim

WORKDIR /app

# Copy the application files
COPY app.py .
# Note: data.csv is no longer needed since file uploads are used

# Install Flask
RUN pip install flask

# Expose port 80
EXPOSE 80

# Run the web application
CMD ["python", "app.py"]
