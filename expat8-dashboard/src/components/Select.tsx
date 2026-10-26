import type { Option } from '@/lib/options';

type Props = {
  label: string;
  name: string;
  options: Option[];
  defaultValue?: string;
  /** Adds a leading empty-value option (e.g. "All"). */
  emptyLabel?: string;
};

export default function Select({ label, name, options, defaultValue, emptyLabel }: Props) {
  return (
    <label>
      {label}
      <select name={name} defaultValue={defaultValue ?? ''}>
        {emptyLabel !== undefined && <option value="">{emptyLabel}</option>}
        {options.map(([value, text]) => <option key={value} value={value}>{text}</option>)}
      </select>
    </label>
  );
}
