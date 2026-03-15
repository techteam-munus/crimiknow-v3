/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    unoptimized: true,
  },
  // Enable experimental features for better streaming support
  experimental: {
    // Ensures streaming responses work correctly on serverless platforms
    serverActions: {
      bodySizeLimit: '2mb',
    },
  },
}

export default nextConfig
