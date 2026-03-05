##############################################################
# Lab 2B — Static Assets: S3 Object Upload
#
# This file manages static files that CloudFront serves via
# the /static/* ordered_cache_behavior defined in
# cloudfront-lab-2a-distribution.tf.
#
# HOW IT WORKS:
# 1. aws_s3_object uploads the file from your local Terraform
#    working directory into the static bucket at apply time.
# 2. CloudFront's /static/* behavior routes requests to the
#    S3 origin (dawgs-armageddon_static_bucket01).
# 3. OAC signs CloudFront's requests to S3 — the bucket
#    is never public. Only CloudFront can read the objects.
# 4. The response headers policy stamps Cache-Control:
#    public, max-age=31536000, immutable on responses,
#    telling browsers to cache the file for 1 year.
#
# TO ADD MORE STATIC FILES:
# Copy the aws_s3_object block below and change:
#   - resource label (e.g. dawgs-armageddon_static_myfile01)
#   - key  (the path CloudFront will serve, e.g. "scripts/setup.sh")
#   - source (path to the file in your Terraform directory)
#   - content_type (match the file type)
##############################################################

# Place user_data.sh in your Terraform directory alongside this file,
# then run terraform apply. The file will be uploaded to S3 and
# immediately available at:
#   https://thedawgs2025.click/static/user_data.sh

resource "aws_s3_object" "dawgs-armageddon_static_user_data01" {
  count = var.enable_cloudfront ? 1 : 0

  bucket = aws_s3_bucket.dawgs-armageddon_static_bucket01[0].id

  # S3 key = the path CloudFront appends after /static/
  # Request: GET /static/user_data.sh
  # CloudFront strips /static/ and fetches key "user_data.sh" from S3
  key = "user_data.sh"

  # Path relative to where you run terraform apply.
  # user_data.sh must be in the same directory as your .tf files.
  source = "${path.module}/user_data.sh"

  # ETag causes Terraform to re-upload the file if its contents change.
  # Without this, Terraform would upload once and never update even if
  # you modify user_data.sh.
  etag = filemd5("${path.module}/user_data.sh")

  # text/x-shellscript is the correct MIME type for shell scripts.
  # This tells browsers and clients what kind of file they received.
  # Without it, S3 defaults to binary/octet-stream, which causes
  # some browsers to download instead of display the file.
  content_type = "text/x-shellscript"

  # The object cannot be created until the bucket policy exists,
  # because the policy is what allows CloudFront to read it.
  # Terraform usually infers this from the bucket reference, but
  # explicit depends_on makes the intent clear and prevents race conditions.
  depends_on = [
    aws_s3_bucket_policy.dawgs-armageddon_static_policy01
  ]

  tags = {
    Name = "${var.project_name}-static-user-data01"
    Lab  = "2B"
  }
}
