resource "aws_route53_zone" "marc_gavanier" {
  for_each = toset(local.domainNames)
  name     = each.value
  tags     = local.tags
}

resource "aws_route53_record" "main_name_servers_record" {
  for_each        = toset(local.domainNames)
  name            = aws_route53_zone.marc_gavanier[each.key].name
  allow_overwrite = true
  ttl             = 30
  type            = "NS"
  zone_id         = aws_route53_zone.marc_gavanier[each.key].zone_id
  records         = aws_route53_zone.marc_gavanier[each.key].name_servers
}

locals {
  subject_alternative_names = {
    for policy_file in fileset("${path.root}/assets/policies", "*") : trimsuffix(policy_file, ".json") => {
      name  = split("_", policy_file)[0]
      label = trimsuffix(split("_", policy_file)[1], ".json")
    }
  }
}

resource "aws_acm_certificate" "marc_gavanier_certificate" {
  provider                  = aws.us-east-1
  domain_name               = local.domainNames[0]
  subject_alternative_names = [for item in local.domainNames : "*.${item}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}

resource "aws_route53_record" "marc_gavanier_domain_names" {
  for_each        = toset(local.domainNames)
  name            = sort(aws_acm_certificate.marc_gavanier_certificate.domain_validation_options[*].resource_record_name)[0]
  depends_on      = [aws_acm_certificate.marc_gavanier_certificate]
  zone_id         = aws_route53_zone.marc_gavanier[each.key].id
  type            = "CNAME"
  ttl             = "300"
  records         = [sort(aws_acm_certificate.marc_gavanier_certificate.domain_validation_options[*].resource_record_value)[0]]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "marc_gavanier_certificate_validation" {
  for_each        = toset(local.domainNames)
  provider        = aws.us-east-1
  certificate_arn = aws_acm_certificate.marc_gavanier_certificate.arn
  validation_record_fqdns = [
    aws_route53_record.marc_gavanier_domain_names[each.key].fqdn,
  ]
  timeouts {
    create = "48h"
  }
}

resource "aws_route53_record" "marc_gavanier_record_ipv4" {
  for_each = toset(local.domainNames)
  name     = aws_route53_zone.marc_gavanier[each.key].name
  zone_id  = aws_route53_zone.marc_gavanier[each.key].zone_id
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.marc_gavanier.domain_name
    zone_id                = aws_cloudfront_distribution.marc_gavanier.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "marc_gavanier_record_ipv6" {
  for_each = toset(local.domainNames)
  name     = aws_route53_zone.marc_gavanier[each.key].name
  zone_id  = aws_route53_zone.marc_gavanier[each.key].zone_id
  type     = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.marc_gavanier.domain_name
    zone_id                = aws_cloudfront_distribution.marc_gavanier.hosted_zone_id
    evaluate_target_health = false
  }
}