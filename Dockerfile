# start by pulling the python image
FROM python:3.9-alpine

# Set environment variables for the desired Node.js and npm versions
ENV NODE_VERSION=18.12.1
#ENV NPM_VERSION=9.6.0

# Add community repository to apk
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

# Install required dependencies
RUN apk update && apk upgrade && \
    apk add bash curl make gcc g++ python3

# Install Node.js and npm
RUN apk add --no-cache nodejs npm

# Check Node.js and npm versions
RUN node -v && npm -v

RUN npm install -g npx yarn


ENTRYPOINT ["bash", "-c"]

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

EXPOSE 8000

# Run our CMD within the virtual environment
CMD ["pipenv run python app.py"]
