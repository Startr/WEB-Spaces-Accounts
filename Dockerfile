# start by pulling the python image
FROM python:3.9-alpine

RUN apk add --update npm
RUN npm install -g npx

# copy the Pipfile and Pipfile.lock from the local file to the image
COPY ./Pipfile /app/Pipfile
COPY ./Pipfile.lock /app/Pipfile.lock

# install pipenv
RUN pip install pipenv

# switch working directory
WORKDIR /app

# install the dependencies and packages in the requirements file
RUN pipenv install 

# copy every content from the local file to the image
COPY . /app

# configure the container to run in an executed manner
ENTRYPOINT [ "python" ]

EXPOSE 8000

CMD ["app.py" ]
