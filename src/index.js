const AWS = require('aws-sdk');
const { WebClient } = require('@slack/web-api');

exports.handler = async (event, context) => {
    console.log('Received event from Slack:', JSON.stringify(event));

    let body;
    let statusCode = '200';
    const headers = {
        'Content-Type': 'application/json',
    };

    try {
        const received_data = JSON.parse(event.body);
        if(received_data.type == 'url_verification') {
            // slackからのhealth checkのための応答
            body = event.body.challenge;
        } else {
            const token = process.env.SLACK_TOKEN;
            const web = new WebClient(token);
        
            const sendToChannelId = process.env.SLACK_CHANNEL_TO_SEND;
            const message = received_data.event;
        
            const result = await web.chat.postMessage({
                text: `channel: ${message.channel}, user: ${message.user}, message: ${message.text}`,
                channel: sendToChannelId
            });
        
            body = `Successfully send message ${result.ts} in conversation ${sendToChannelId}`;
        }
    } catch (err) {
        statusCode = '400';
        body = err.message;
    } finally {
        body = JSON.stringify(body);
    }

    return {
        statusCode,
        body,
        headers,
    };
};