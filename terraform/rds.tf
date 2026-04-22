resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "app" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = local.db_subnet_ids

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-db-subnets" })
}

resource "aws_db_parameter_group" "app" {
  name        = "${local.name_prefix}-postgres"
  family      = var.db_parameter_group_family
  description = "Parameter group for ${local.name_prefix} PostgreSQL."

  tags = local.common_tags
}

resource "aws_db_instance" "app" {
  identifier                      = "${local.name_prefix}-postgres"
  engine                          = "postgres"
  engine_version                  = var.db_engine_version
  db_name                         = var.db_name
  username                        = var.db_username
  password                        = random_password.db_password.result
  instance_class                  = var.db_instance_class
  allocated_storage               = var.db_allocated_storage
  max_allocated_storage           = var.db_max_allocated_storage
  storage_type                    = "gp3"
  storage_encrypted               = true
  backup_retention_period         = var.db_backup_retention_period
  multi_az                        = var.db_multi_az
  port                            = var.db_port
  publicly_accessible             = var.db_publicly_accessible
  deletion_protection             = var.db_deletion_protection
  skip_final_snapshot             = var.db_skip_final_snapshot
  final_snapshot_identifier       = var.db_skip_final_snapshot ? null : "${local.name_prefix}-postgres-final"
  performance_insights_enabled    = var.db_performance_insights_enabled
  copy_tags_to_snapshot           = true
  auto_minor_version_upgrade      = true
  apply_immediately               = false
  db_subnet_group_name            = aws_db_subnet_group.app.name
  parameter_group_name            = aws_db_parameter_group.app.name
  vpc_security_group_ids          = [aws_security_group.db.id]
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-postgres" })
}

resource "aws_secretsmanager_secret" "app_database" {
  name                    = "${local.name_prefix}/app/database"
  recovery_window_in_days = var.db_secret_recovery_window_in_days

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app_database" {
  secret_id = aws_secretsmanager_secret.app_database.id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.app.address
    port     = aws_db_instance.app.port
    username = var.db_username
    password = random_password.db_password.result
    dbname   = var.db_name
    database_url = format(
      "postgresql://%s:%s@%s:%d/%s",
      urlencode(var.db_username),
      urlencode(random_password.db_password.result),
      aws_db_instance.app.address,
      var.db_port,
      var.db_name,
    )
  })
}
