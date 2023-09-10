# start by pulling the python image
FROM python:3.9-alpine

# Set environment variables for the desired Node.js and npm versions
ENV NODE_VERSION=18.12.1
ENV NPM_VERSION=9.6.0
ENV NVM_DIR /usr/local/nvm 



# Install required dependencies
RUN apk update && apk upgrade && \
    apk add bash curl make gcc g++ python3

RUN curl https://raw.githubusercontent.com/creationix/nvm/v0.39.5/install.sh | bash
RUN . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH      $NVM_DIR/v$NODE_VERSION/bin:$PATH


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