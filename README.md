# Extract Attachments from FreeAgent

FreeAgent allow you to export all of your data to XLS, but they don't offer
simple way to grab your attached files (receipts/bills etc.)

This project will grab all attachments for Bills and Bank Transactions.

## Requirements

You will need to set up a FreeAgent developer account and create an
'application' to access the API.

You should set the OAUTH redirect uri to:

`http://localhost:4567/auth_endpoint`

## Setup

Create a `.env` file and add the following:

```sh
CLIENT_ID='<your app id>'
CLIENT_SECRET='<your app secret>'
```

## Getting an access token

To access your freeagent account you will need an OAuth Access Token.

There is a sinatra app in the project to help you find it.

run `bundle exec rackup` and [click here](http://localhost:4567)

Then follow the process to authorise, and exchange tokens.

Once you have your access token, add it to your `.env` file.

```sh
CLIENT_ID='<your app id>'
CLIENT_SECRET='<your app secret>'
ACCESS_TOKEN='<your access token>'
```

## Retrieving attachments

Once you have your access key you can execute the script to download
attachments:

```
bundle exec ruby fetch.rb [path]
```
