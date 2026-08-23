package com.wso2.employeeconcierge.payroll;

import io.grpc.Metadata;
import io.grpc.ServerCall;
import io.grpc.ServerCallHandler;
import io.grpc.ServerInterceptor;
import io.grpc.Status;
import io.quarkus.grpc.GlobalInterceptor;
import jakarta.enterprise.context.ApplicationScoped;
import org.a2aproject.sdk.grpc.A2AServiceGrpc;
import org.eclipse.microprofile.config.inject.ConfigProperty;

/**
 * Gates only the GetExtendedAgentCard RPC behind a real bearer-token check.
 *
 * <p>The a2a-java gRPC reference module (1.1.0.Final) has no per-request
 * extended-card modifier hook the way the Python SDK does — its
 * getExtendedAgentCard() is a fixed, context-free bean lookup (confirmed
 * by reading GrpcHandler/QuarkusGrpcHandler source). So rather than
 * downgrading the card's content per caller like PeopleOperations does,
 * this rejects the RPC outright for anyone without the admin token — a
 * different, still-genuine answer to the same requirement, working within
 * what this SDK version actually offers. Every other RPC on the service is
 * untouched: this interceptor only inspects the one method name it cares
 * about and calls next.startCall for everything else.
 */
@ApplicationScoped
@GlobalInterceptor
public class AdminOnlyExtendedCardInterceptor implements ServerInterceptor {

  private static final Metadata.Key<String> AUTHORIZATION =
      Metadata.Key.of("authorization", Metadata.ASCII_STRING_MARSHALLER);

  @ConfigProperty(name = "payroll.admin-token")
  String adminToken;

  @Override
  public <ReqT, RespT> ServerCall.Listener<ReqT> interceptCall(
      final ServerCall<ReqT, RespT> call, final Metadata headers,
      final ServerCallHandler<ReqT, RespT> next) {
    String fullMethod = call.getMethodDescriptor().getFullMethodName();
    String extendedCardMethod = A2AServiceGrpc.getGetExtendedAgentCardMethod().getFullMethodName();
    if (!fullMethod.equals(extendedCardMethod)) {
      return next.startCall(call, headers);
    }

    String expected = "Bearer " + adminToken;
    String actual = headers.get(AUTHORIZATION);
    if (adminToken.isEmpty() || actual == null || !actual.equals(expected)) {
      call.close(Status.PERMISSION_DENIED.withDescription(
          "GetExtendedAgentCard requires a valid admin bearer token"), new Metadata());
      return new ServerCall.Listener<>() { };
    }
    return next.startCall(call, headers);
  }
}
