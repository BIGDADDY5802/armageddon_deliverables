# commands from 1b

```
aws ssm get-parameters \
  --names /lab/db/endpoint /lab/db/port /lab/db/name \
  --with-decryption
```

```
  aws secretsmanager get-secret-value \
  --secret-id lab/rds/mysql
```

```
aws ssm get-parameter --name /lab/db/endpoint
aws secretsmanager get-secret-value --secret-id lab/rds/mysql
```

```
aws logs describe-log-groups \
  --log-group-name-prefix /aws/ec2/lab-rds-app
```

```
aws logs filter-log-events \
  --log-group-name /aws/ec2/lab-rds-app \
  --filter-pattern "ERROR"
```

```
aws cloudwatch describe-alarms \
  --alarm-name-prefix lab-db-connection
```

```
curl http://44.200.161.199/list
```




