# start by pulling the python image
FROM python:3.9-alpine

RUN apk add --update nodejs nodejs-npm npx

# copy the requirements file into the image
COPY ./requirements.txt /app/requirements.txt

# switch working directory
WORKDIR /app

# install the dependencies and packages in the requirements file
RUN pip install -r requirements.txt

# copy every content from the local file to the image
COPY . /app

# configure the container to run in an executed manner
ENTRYPOINT [ "python" ]

EXPOSE 8000

CMD ["app.py" ]
