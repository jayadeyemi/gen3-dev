package controllers

import (
	"context"
	"fmt"
	"time"

	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	// Import the ACK API packages for S3 and CloudFront.
	// Ensure these imports match the paths where ACK provides the Go types for the resources.
	s3v1alpha1 "github.com/aws-controllers-k8s/s3-controller/apis/v1alpha1"
	cloudfrontv1alpha1 "github.com/aws-controllers-k8s/cloudfront-controller/apis/v1alpha1"
)

// S3BucketReconciler reconciles an ACK S3 Bucket object.
type S3BucketReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// Reconcile watches for changes in the S3 Bucket resource.
func (r *S3BucketReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// Fetch the S3 Bucket resource.
	var bucket s3v1alpha1.Bucket
	if err := r.Get(ctx, req.NamespacedName, &bucket); err != nil {
		if errors.IsNotFound(err) {
			logger.Info("S3 Bucket resource not found. Ignoring since it might have been deleted", "name", req.NamespacedName)
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	// Check if the website endpoint is available in the Bucket's status.
	websiteEndpoint := bucket.Status.WebsiteEndpoint
	if websiteEndpoint == "" {
		logger.Info("Website endpoint not yet available for bucket", "BucketName", bucket.Spec.BucketName)
		// Requeue after 30 seconds to check again.
		return ctrl.Result{RequeueAfter: 30 * time.Second}, nil
	}
	logger.Info("Website endpoint detected for bucket", "Endpoint", websiteEndpoint)

	// Fetch the CloudFront Distribution resource.
	var distribution cloudfrontv1alpha1.Distribution
	distributionName := "cloudfront-distribution" // Assumes a fixed name; adjust as needed.
	if err := r.Get(ctx, client.ObjectKey{Namespace: req.Namespace, Name: distributionName}, &distribution); err != nil {
		if errors.IsNotFound(err) {
			logger.Info("CloudFront Distribution not found; skipping update", "name", distributionName)
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	// Assume the origin ID follows this format. Adjust if you use a different identifier.
	expectedOriginID := fmt.Sprintf("S3-Website-%s.s3-website-%s.amazonaws.com", bucket.Spec.BucketName, bucket.Spec.Region)
	updated := false

	// Loop through all origins to find the one that matches.
	for i, origin := range distribution.Spec.DistributionConfig.Origins {
		if origin.Id == expectedOriginID {
			if origin.DomainName != websiteEndpoint {
				// Update the domainName with the computed website endpoint.
				distribution.Spec.DistributionConfig.Origins[i].DomainName = websiteEndpoint
				updated = true
				logger.Info("Updating CloudFront origin domainName", "ExpectedOriginID", expectedOriginID, "NewDomainName", websiteEndpoint)
			}
		}
	}

	if updated {
		// Update the CloudFront distribution resource.
		if err := r.Update(ctx, &distribution); err != nil {
			logger.Error(err, "Failed to update CloudFront distribution")
			return ctrl.Result{}, err
		}
		logger.Info("CloudFront distribution updated successfully")
	} else {
		logger.Info("No update required for CloudFront distribution")
	}

	return ctrl.Result{}, nil
}

// SetupWithManager registers this controller with the Manager.
func (r *S3BucketReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&s3v1alpha1.Bucket{}).
		Complete(r)
}