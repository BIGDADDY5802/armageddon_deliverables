############################################
# Lab 2B-Honors+ - Optional invalidation action (run on demand)
############################################

# Explanation: This is Chewbacca’s “break glass” lever — use it sparingly or the bill will bite.
# resource "null_resource" "dawgs-armageddon_invalidate_index01" {
#   triggers = {
#     # Re-runs invalidation whenever the static file changes
#     file_hash = filemd5("${path.module}/user_data.sh")
#   }

#   provisioner "local-exec" {
#     command = <<EOT
#       aws cloudfront create-invalidation \
#         --distribution-id ${aws_cloudfront_distribution.dawgs-armageddon_cf01[0].id} \
#         --paths "/static/user_data.sh" "/*"
#     EOT
#   }
# }

