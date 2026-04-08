# AgentCore Backend Services

This directory contains the Python backend services for the AgentCore 3LO OAuth implementation.

## Structure

```
backend/
├── runtime/              # Main agent runtime service
│   ├── agent/           # Agent logic and tools
│   ├── app/             # FastAPI application
│   ├── services/        # Business logic services
│   ├── Dockerfile       # Container image for agent
│   └── requirements.txt # Python dependencies
│
├── session_binding/     # OAuth session binding service
│   ├── app/            # FastAPI application
│   ├── Dockerfile      # Container image for session binding
│   └── requirements.txt # Python dependencies
│
└── shared/             # Shared utilities
    └── alb_auth.py     # ALB OAuth header parsing
```

## Services

### Agent Runtime (`runtime/`)

The main agent service that:
- Handles agent invocations via FastAPI
- Integrates with AWS Bedrock for AI capabilities
- Uses AgentCore Identity for authentication
- Provides GitHub tools for repository operations

**Port**: 8000
**Health Check**: `/health`
**API Docs**: `/docs`

### Session Binding (`session_binding/`)

OAuth session binding service that:
- Handles OAuth 2.0 authorization code flow
- Binds user sessions to AgentCore Identity
- Stores session state in S3
- Provides success page after OAuth completion

**Port**: 8001
**Health Check**: `/health`
**Callback Endpoint**: `/session-binding`

## Development

### Prerequisites

- Python 3.13+
- Docker (for containerized development)
- AWS credentials with appropriate permissions

### Local Development

#### Agent Runtime

```bash
cd runtime/

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export AWS_REGION=us-east-1
export WORKLOAD_IDENTITY_NAME=your-workload-identity
export S3_BUCKET=your-session-bucket
export COGNITO_USER_POOL_ID=us-east-1_xxxxx
export COGNITO_CLIENT_ID=xxxxx
export COGNITO_CLIENT_SECRET=xxxxx
export COGNITO_DOMAIN=your-app.auth.us-east-1.amazoncognito.com
export GITHUB_PROVIDER_NAME=github-oauth-client-xxxxx

# Run the service
python main.py
```

#### Session Binding

```bash
cd session_binding/

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export AWS_REGION=us-east-1
export WORKLOAD_IDENTITY_NAME=your-workload-identity
export S3_BUCKET=your-session-bucket
export COGNITO_USER_POOL_ID=us-east-1_xxxxx
export COGNITO_CLIENT_ID=xxxxx
export COGNITO_CLIENT_SECRET=xxxxx

# Run the service
python main.py
```

### Docker Build

#### Agent Runtime

```bash
cd runtime/
docker build -t agentcore-agent:latest .
docker run -p 8000:8000 \
  -e AWS_REGION=us-east-1 \
  -e WORKLOAD_IDENTITY_NAME=your-workload-identity \
  agentcore-agent:latest
```

#### Session Binding

```bash
cd session_binding/
docker build -t agentcore-session-binding:latest .
docker run -p 8001:8001 \
  -e AWS_REGION=us-east-1 \
  -e WORKLOAD_IDENTITY_NAME=your-workload-identity \
  agentcore-session-binding:latest
```

## Environment Variables

### Agent Runtime

| Variable | Description | Required |
|----------|-------------|----------|
| `AWS_REGION` | AWS region | Yes |
| `WORKLOAD_IDENTITY_NAME` | AgentCore workload identity name | Yes |
| `S3_BUCKET` | S3 bucket for session storage | Yes |
| `COGNITO_USER_POOL_ID` | Cognito user pool ID | Yes |
| `COGNITO_CLIENT_ID` | Cognito app client ID | Yes |
| `COGNITO_CLIENT_SECRET` | Cognito app client secret | Yes |
| `COGNITO_DOMAIN` | Cognito domain | Yes |
| `GITHUB_PROVIDER_NAME` | GitHub OAuth provider name | Yes |
| `LOG_LEVEL` | Logging level (default: INFO) | No |

### Session Binding

| Variable | Description | Required |
|----------|-------------|----------|
| `AWS_REGION` | AWS region | Yes |
| `WORKLOAD_IDENTITY_NAME` | AgentCore workload identity name | Yes |
| `S3_BUCKET` | S3 bucket for session storage | Yes |
| `COGNITO_USER_POOL_ID` | Cognito user pool ID | Yes |
| `COGNITO_CLIENT_ID` | Cognito app client ID | Yes |
| `COGNITO_CLIENT_SECRET` | Cognito app client secret | Yes |
| `LOG_LEVEL` | Logging level (default: INFO) | No |

## API Endpoints

### Agent Runtime

- `GET /health` - Health check endpoint
- `POST /invocations` - Invoke the agent with a prompt
- `GET /docs` - OpenAPI documentation (Swagger UI)

### Session Binding

- `GET /health` - Health check endpoint
- `GET /session-binding` - OAuth callback endpoint
- `GET /docs` - OpenAPI documentation (Swagger UI)

## Authentication Flow

1. User accesses agent endpoint through ALB
2. ALB redirects to Cognito for authentication
3. After Cognito login, user is redirected to `/session-binding`
4. Session binding service:
   - Receives authorization code from Cognito
   - Exchanges code for tokens
   - Stores session in S3
   - Binds session to AgentCore Identity
5. User is redirected back to agent with session cookie
6. Agent validates session from ALB headers
7. Agent uses AgentCore Identity for 3LO OAuth with GitHub

## Dependencies

### Agent Runtime

See `runtime/requirements.txt`:
- `fastapi` - Web framework
- `boto3` - AWS SDK
- `anthropic` - Bedrock integration
- `pydantic` - Data validation
- `requests` - HTTP client for GitHub API

### Session Binding

See `session_binding/requirements.txt`:
- `fastapi` - Web framework
- `boto3` - AWS SDK
- `pydantic` - Data validation
- `jinja2` - Template rendering

## Deployment

These services are deployed as ECS Fargate tasks behind an Application Load Balancer. See the [deployment guide](../README.md) for full instructions.

### Push to ECR

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build and push agent
cd runtime/
docker build -t <account-id>.dkr.ecr.us-east-1.amazonaws.com/agentcore-agent:latest .
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/agentcore-agent:latest

# Build and push session binding
cd ../session_binding/
docker build -t <account-id>.dkr.ecr.us-east-1.amazonaws.com/agentcore-session-binding:latest .
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/agentcore-session-binding:latest
```

## Troubleshooting

### Agent Won't Start

Check CloudWatch logs:
```bash
aws logs tail /ecs/agentcore-prod/agent --follow --region us-east-1
```

Common issues:
- Missing environment variables
- IAM permissions not configured
- Workload identity not found
- S3 bucket not accessible

### Session Binding Fails

Check CloudWatch logs:
```bash
aws logs tail /ecs/agentcore-prod/session-binding --follow --region us-east-1
```

Common issues:
- Cognito callback URL not configured
- OAuth credentials invalid
- S3 bucket permissions incorrect

### Authentication Errors

Verify ALB OAuth configuration:
- Cognito callback URL matches ALB URL
- Cognito app client has correct OAuth settings
- ALB listener rules are configured correctly

## Testing

```bash
# Test agent health
curl http://localhost:8000/health

# Test session binding health
curl http://localhost:8001/health

# Test agent invocation (requires valid session)
curl -X POST http://localhost:8000/invocations \
  -H "Content-Type: application/json" \
  -d '{"prompt": "List my GitHub repositories"}'
```

## Security Notes

- All secrets should be stored in AWS Secrets Manager
- Never commit credentials or API keys
- Use IAM roles for AWS service access
- Enable CloudWatch logging for audit trail
- Use HTTPS only in production
- Validate all user inputs
- Follow principle of least privilege for IAM roles
