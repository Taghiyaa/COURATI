interface LogoProps {
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}

const sizeClasses = {
  sm: 'w-12 h-12',
  md: 'w-16 h-16',
  lg: 'w-24 h-24',
};

export default function Logo({ size = 'md', className = '' }: LogoProps) {
  return (
    <div className={`${sizeClasses[size]} ${className}`}>
      <img src="/logo.png" alt="Courati" className="w-full h-full object-contain" />
    </div>
  );
}
