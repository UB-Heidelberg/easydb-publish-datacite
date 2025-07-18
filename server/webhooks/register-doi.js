// easyDB Datacite Webhook plugin
const fs = require('fs');
const querystring = require('querystring');

// Read configuration
const config = require('../../config.js');

/**
 * Helper Function to parse a JSON payload from stdin
 * @returns {Promise<Object>}
 */
async function readPayload() {
  let input = '';
  for await (const chunk of process.stdin) input = input + chunk;
  return JSON.parse(input);
}

function returnAndLogJsonError(error, status = 500) {
  let description;
  if (error instanceof Error) {
    log(error.stack, 'ERROR');
    description = error.toString();
  }
  else {
    log(error, 'ERROR');
    description = error;
  }
  const output = {
    'code': 'error.api.generic', // define in l10n
    "error": description,
    "params": {description}, // map to ender the error code localization
    "realm": "api", // this should always be "api"
    "statuscode": status // an optional status code
  };
  process.stdout.write(JSON.stringify(output));
}

function authHeader(username, password) {
  return 'Basic ' + Buffer.from(`${username}:${password}`).toString('base64')
}

function log(messageOrObject, level='INFO') {
  // Check to see if the message log has been initialized
  if ( typeof log.messages == 'undefined' ) {
    // It has not... perform the initialization
    log.messages = [];
  }
  let entry = {
    "timestamp": new Date().toISOString(),
    "message": messageOrObject,
    "level": level
  };
  console.error(entry.timestamp, entry.level, entry.message);
  log.messages.push(entry);
}

async function postEvent(fylrUrl, accessToken, objectType, objectVersion, objectId) {
  const type = "PUBLISH_DATACITE_DOI_REGISTERED";
  const event = {
    'type': type,
    'objecttype': objectType,
    'object_id': objectId,
    'object_version': objectVersion,
    'info': {
      'log': log.messages
    }
  }
  const res = await fetch(fylrUrl + '/api/v1/event?background=1', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + accessToken
    },
    body: JSON.stringify(event),
  });
  if (!res.ok) {
    returnAndLogJsonError(`postEvent failed POST, status = ${res.status}, statustext = ${res.statusText}`);
  }
}

async function registerDoiForObject(dbObject, publishOpts, dataciteOpts) {
  const { username, password, endpoint: dataciteEndpoint, doiPrefix} = dataciteOpts;
  const { xsltName, token: accessToken, collector , apiUrl: apiUrl, externalUrl: externalUrl} = publishOpts;
  const dataciteAuth = authHeader(username, password);
  const systemObjectId = dbObject._system_object_id;
  const doi = `${doiPrefix}${systemObjectId}`;

  let metadataXml = await getMetadataFromDb(systemObjectId, xsltName, apiUrl);
  metadataXml = metadataXml.replace('___DOI_PLACEHOLDER___', doi);

  const dataciteMetadataUrl = dataciteEndpoint + '/metadata/' + doi;
  log(`PUT metadata to ${dataciteMetadataUrl}`);
  const dataciteMetadataResponse = await fetch(dataciteMetadataUrl, {
    method: 'PUT',
    body: metadataXml,
    headers: {
      'Content-Type': 'application/xml;charset=utf-8',
      'Authorization': dataciteAuth,
    }
  })
  const dataciteMetadataResponseText = await dataciteMetadataResponse.text();
  if (!dataciteMetadataResponse.ok) {
    throw Error('Failed Datacite metadata registration: '
      + `${dataciteMetadataResponse.status} ${dataciteMetadataResponse.statusText}, response: ${dataciteMetadataResponseText}, request body: ${metadataXml}`);
  }
  log('Success, response: ' + dataciteMetadataResponseText);

  const objectDetailUrl = `${externalUrl}/detail/${systemObjectId}`;
  const dataciteMintUrl = `${dataciteEndpoint}/doi/${doi}`;
  const body = `doi=${doi}\nurl=${objectDetailUrl}\n`
  log(`PUT ${dataciteMintUrl} with body: ${body}`);
  const dataciteMintResponse = await fetch(dataciteMintUrl, {
    method: 'PUT',
    body,
    headers: {
      'Content-Type': 'text/plain;charset=UTF-8',
      'Authorization': dataciteAuth,
    }
  })
  const dataciteMintResponseText = await dataciteMintResponse.text();
  if (!dataciteMintResponse.ok) {
    throw Error('Failed Datacite url registration: '
      + `${dataciteMintResponse.status} ${dataciteMintResponse.statusText}, response: ${dataciteMintResponseText}`);
  }
  log('Success, response: ' + dataciteMintResponseText);

  const publish = {
    system_object_id: systemObjectId,
    collector,
    publish_uri: 'https://doi.org/' + doi,
    easydb_uri: objectDetailUrl
  }

  return { published: await postPublishedDoiToDb(publish, apiUrl, accessToken) };
}

async function getMetadataFromDb(systemObjectId, xsltName, easyDbUrl) {
  const metadataUrl = easyDbUrl + '/api/v1/objects/id/' + systemObjectId + '/format/xslt/' + xsltName;
  const metadataResponse = await fetch(metadataUrl);
  const metadataResponseBody = await metadataResponse.text();
  if (!metadataResponse.ok) {
    throw Error('Failed getting metadata from db: '
      + `${metadataResponse.status} ${metadataResponse.statusText}, response: ${metadataResponseBody}`);
  }
  log(`Got metadata for systemObjectId = ${systemObjectId}`);
  return metadataResponseBody;
}

async function postPublishedDoiToDb(publishObject, apiUrl, accessToken) {
  const publishApiUrl = apiUrl + '/api/v1/publish?access_token=' + accessToken;
  log(`POST ${publishApiUrl}, with publish object:`);
  log(publishObject);
  const publishResponse = await fetch(publishApiUrl,
  {
    method: 'post',
    body: JSON.stringify([{publish: publishObject}])
  })
  const publishResponseObject = await publishResponse.json();
  if (!publishResponse.ok ) {
    throw Error(`Failed API publish: ${publishResponse.status} ${publishResponse.statusText}, response: `
      + JSON.stringify(publishResponseObject));
  }

  log('Success, response:');
  log(publishResponseObject);
  return publishResponseObject;
}


async function main() {
  const info = JSON.parse(process.argv[2]);
  const input = await readPayload()
  const externalUrl = info.external_url;
  const apiUrl = info.api_url;
  const accessToken = info.api_user_access_token;

  // Parse query parameters
  var {useConfig = 'test'} = info.request.query;
  // Parse body
  if (!input) {
    returnAndLogJsonError('Missing request body', 400);
    return;
  }
  log(`Using config ${useConfig}`);
  log(process.env);

  const opts = Object.assign({ token: accessToken, apiUrl: apiUrl, externalUrl: externalUrl}, config.easyDb);
  try {
    log(info.request.header);
    Promise.all(input.objects.map( dbObject => registerDoiForObject(dbObject, opts, config.datacite[useConfig]) )).then( statuses => {
      log('All registerDoiForObject finished successfully');
      postEvent(apiUrl,accessToken)
      process.stdout.write(JSON.stringify({status: statuses}));
    }).catch(error => {
      postEvent(apiUrl,accessToken)
      returnAndLogJsonError(error);
    })
  }
  catch (error) {
    returnAndLogJsonError(error);
  }

}

main().catch(console.error);
