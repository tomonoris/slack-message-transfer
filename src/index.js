const { WebClient } = require("@slack/web-api");

exports.handler = async (event) => {
  console.log("Received event from Slack:", JSON.stringify(event));

  let body;
  let statusCode = "200";
  const headers = {
    "Content-Type": "application/json",
  };

  try {
    const ReceivedData = JSON.parse(event.body);
    if (ReceivedData.type === "url_verification") {
      // slackからのhealth checkのための応答
      body = ReceivedData.challenge;
    } else {
      const token = process.env.SLACK_TOKEN;
      const web = new WebClient(token);

      const sendToChannelId = process.env.SLACK_CHANNEL_TO_SEND;
      const message = ReceivedData.event;

      const result = await web.chat.postMessage({
        text: `channel: ${message.channel}, user: ${message.user}, message: ${message.text}`,
        channel: sendToChannelId,
      });

      body = `Successfully send message of ${message.text} in ${result.ts}`;
    }
  } catch (err) {
    statusCode = "400";
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
