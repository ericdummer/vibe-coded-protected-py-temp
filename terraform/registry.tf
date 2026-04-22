resource "aws_ecr_repository" "app" {
  count = local.use_ecr ? 1 : 0

  name                 = local.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, { Name = local.ecr_repository_name })
}

resource "aws_ecr_lifecycle_policy" "app" {
  count = local.use_ecr ? 1 : 0

  repository = aws_ecr_repository.app[0].name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the most recent 30 images."
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
