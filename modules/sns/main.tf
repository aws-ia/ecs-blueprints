# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

/*====================================================
      AWS SNS topic for deployment notifications
=====================================================*/

resource "aws_sns_topic" "sns_notification" {
  name = var.sns_name
}

data "aws_iam_policy_document" "notification_access" {
  statement {
    actions = ["sns:Publish"]

    principals {
      type        = "Service"
      identifiers = ["codestar-notifications.amazonaws.com"]
    }

    resources = [aws_sns_topic.sns_notification.arn]
  }
}

resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.sns_notification.arn
  policy = data.aws_iam_policy_document.notification_access.json
}
