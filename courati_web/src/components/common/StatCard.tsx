import type { LucideIcon } from 'lucide-react';
import { formatNumber } from '../../lib/utils';

interface StatCardProps {
  title: string;
  value: number | string;
  icon: LucideIcon;
  color: 'blue' | 'green' | 'purple' | 'orange' | 'red' | 'indigo' | 'teal' | 'yellow' | 'primary';
  trend?: number | string;
}

const colorClasses = {
  blue: 'bg-blue-100 text-blue-600',
  green: 'bg-green-100 text-green-600',
  purple: 'bg-purple-100 text-purple-600',
  orange: 'bg-orange-100 text-orange-600',
  red: 'bg-red-100 text-red-600',
  indigo: 'bg-indigo-100 text-indigo-600',
  teal: 'bg-teal-100 text-teal-600',
  yellow: 'bg-yellow-100 text-yellow-600',
  primary: 'bg-primary-100 text-primary-600',
};

export default function StatCard({ title, value, icon: Icon, color, trend }: StatCardProps) {
  const displayValue = typeof value === 'number' ? formatNumber(value) : value;

  return (
    <div className="bg-white rounded-xl p-6 border border-gray-200 hover:shadow-lg transition-shadow">
      <div className="flex items-center justify-between">
        <div className="flex-1">
          <p className="text-sm text-gray-600 mb-1">{title}</p>
          <p className="text-2xl font-bold text-gray-900">{displayValue}</p>
          {trend !== undefined && (
            <p className="text-sm mt-1 text-gray-600">
              {typeof trend === 'number' ? (
                <span className={trend >= 0 ? 'text-green-600' : 'text-red-600'}>
                  {trend >= 0 ? '↗' : '↘'} {Math.abs(trend)}% vs mois dernier
                </span>
              ) : (
                <span>{trend}</span>
              )}
            </p>
          )}
        </div>
        <div className={`w-12 h-12 rounded-lg flex items-center justify-center ${colorClasses[color]}`}>
          <Icon className="h-6 w-6" />
        </div>
      </div>
    </div>
  );
}
