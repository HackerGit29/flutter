import React, { useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Typography,
  ToggleButtonGroup,
  ToggleButton
} from '@mui/material';
import MapRoundedIcon from '@mui/icons-material/MapRounded';
import WhatshotRoundedIcon from '@mui/icons-material/WhatshotRounded';
import FileDownloadRoundedIcon from '@mui/icons-material/FileDownloadRounded';
import RouterRoundedIcon from '@mui/icons-material/RouterRounded';
import { useQuery } from '@tanstack/react-query';
import { useAppStore } from '../store/useAppStore';
import { getCoverage, getHeatmap } from '../api/operations';
import type { CoverageCluster, CoverageZone } from '../types/admin';

type DisplayZone = {
  id: string;
  name: string;
  city: string;
  lat: number;
  lng: number;
  boxes: number;
  vip: number;
  kwh: number;
  target: number;
  clients: number;
  isActive: boolean;
};

export const CoveragePage: React.FC = () => {
  const { language } = useAppStore();
  const [viewMode, setViewMode] = useState<'boxes' | 'energy'>('boxes');
  const [selectedZoneId, setSelectedZoneId] = useState<string | null>(null);

  const coverageQuery = useQuery({
    queryKey: ['admin-api', 'geo', 'coverage'],
    queryFn: () => getCoverage({ precision: 5 }),
  });
  const heatmapQuery = useQuery({
    queryKey: ['admin-api', 'geo', 'heatmap', viewMode],
    queryFn: () => getHeatmap({ metric: viewMode === 'boxes' ? 'boxes' : 'kwh' }),
  });

  const zones = coverageQuery.data?.zones ?? [];
  const clusters = coverageQuery.data?.clusters ?? [];
  const heatPoints = heatmapQuery.data?.points ?? [];
  const displayZones: DisplayZone[] = useMemo(() => {
    if (!zones.length) {
      return clusters.map((cluster: CoverageCluster) => ({
        id: cluster.geohash,
        name: `Cluster ${cluster.geohash}`,
        city: cluster.geohash,
        lat: cluster.lat,
        lng: cluster.lng,
        boxes: cluster.box_count,
        vip: cluster.vip_count,
        kwh: cluster.kwh ?? 0,
        target: 0,
        clients: cluster.user_count,
        isActive: true,
      }));
    }
    return zones.map((zone: CoverageZone) => ({
      id: zone.id,
      name: zone.name,
      city: zone.name,
      lat: zone.center_lat,
      lng: zone.center_lng,
      boxes: zone.current_clients,
      vip: zone.vip_count,
      kwh: zone.kwh_30d,
      target: zone.target_clients,
      clients: zone.current_clients,
      isActive: zone.is_active,
    }));
  }, [clusters, zones]);
  const selectedZone = displayZones.find((zone) => zone.id === selectedZoneId) ?? displayZones[0] ?? null;

  const projectCoords = (lat: number, lng: number) => {
    const x = ((lng - (-5)) / (9 - (-5))) * 500 + 40;
    const y = ((51.5 - lat) / (51.5 - 42.2)) * 440 + 30;
    return { x, y };
  };

  const handleExportCSV = () => {
    const rows = displayZones.map((zone) => [
      zone.id,
      zone.name,
      zone.lat,
      zone.lng,
      zone.boxes,
      zone.vip,
      zone.kwh,
      zone.target,
    ]);
    const csv = [
      ['ID', 'Nom', 'Latitude', 'Longitude', 'Clients', 'VIP', 'kWh 30j', 'Objectif'],
      ...rows,
    ].map((row) => row.map((value) => `"${String(value).replace(/"/g, '""')}"`).join(',')).join('\n');
    const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8;' }));
    const link = document.createElement('a');
    link.href = url;
    link.download = 'aricie_couverture_geomarketing.csv';
    link.click();
    URL.revokeObjectURL(url);
  };

  const isLoading = coverageQuery.isLoading || heatmapQuery.isLoading;
  const error = coverageQuery.error ?? heatmapQuery.error;
  const metricByCoordinate = new Map(heatPoints.map((point) => [`${point.lat}:${point.lng}`, point.weight]));

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      <Box sx={{ display: 'flex', flexDirection: { xs: 'column', sm: 'row' }, alignItems: { xs: 'flex-start', sm: 'center' }, justifyContent: 'flex-end', gap: 2 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, flexWrap: 'wrap' }}>
          <ToggleButtonGroup
            value={viewMode}
            exclusive
            onChange={(_, value) => value && setViewMode(value)}
            sx={{ backgroundColor: 'background.paper', borderRadius: 0, '& .MuiToggleButton-root': { borderRadius: 0, color: 'text.secondary', borderColor: 'divider', px: 2, py: 0.8, fontSize: '0.8rem', fontWeight: 600, textTransform: 'none', '&.Mui-selected': { backgroundColor: 'primary.main', color: 'text.primary' } } }}
          >
            <ToggleButton value="boxes"><RouterRoundedIcon sx={{ fontSize: 18, mr: 1 }} />{language === 'fr' ? 'Parc de boîtiers' : 'IoT Boxes Fleet'}</ToggleButton>
            <ToggleButton value="energy"><WhatshotRoundedIcon sx={{ fontSize: 18, mr: 1 }} />{language === 'fr' ? 'Heatmap Énergie' : 'Energy Heatmap'}</ToggleButton>
          </ToggleButtonGroup>
          <Button variant="outlined" onClick={handleExportCSV} startIcon={<FileDownloadRoundedIcon />} disabled={!displayZones.length} sx={{ backgroundColor: 'background.paper', borderColor: 'divider', color: 'text.primary', px: 2, py: 0.8, borderRadius: 0, fontSize: '0.82rem', fontWeight: 600 }}>
            {language === 'fr' ? 'Exporter CSV' : 'Export CSV'}
          </Button>
        </Box>
      </Box>

      {error && <Alert severity="error" action={<Button color="inherit" size="small" onClick={() => { void coverageQuery.refetch(); void heatmapQuery.refetch(); }}>{language === 'fr' ? 'Réessayer' : 'Retry'}</Button>}>{error instanceof Error ? error.message : 'Erreur API'}</Alert>}
      {isLoading && <Box role="status" sx={{ display: 'flex', justifyContent: 'center', py: 5 }}><CircularProgress /></Box>}

      {!isLoading && !error && !displayZones.length && <Alert severity="info">{language === 'fr' ? 'Aucune donnée de couverture disponible.' : 'No coverage data available.'}</Alert>}

      {!isLoading && !error && displayZones.length > 0 && (
        <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', lg: '1fr 380px' }, gap: 2.5 }}>
          <Card sx={{ backgroundColor: 'background.paper', border: '1px solid', borderColor: 'divider', overflow: 'hidden' }}>
            <CardContent sx={{ p: { xs: 2, md: 3 } }}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                <MapRoundedIcon sx={{ color: 'primary.main', fontSize: 20 }} />
                <Typography sx={{ fontWeight: 700, fontSize: '0.95rem', color: 'text.primary' }}>{language === 'fr' ? 'Clusters géographiques et zones' : 'Geographic clusters and zones'}</Typography>
              </Box>
              <Box sx={{ width: '100%', height: 480, backgroundColor: 'action.hover', border: '1px solid', borderColor: 'divider', position: 'relative', overflow: 'hidden' }}>
                <svg viewBox="0 0 600 520" style={{ width: '100%', height: '100%' }} aria-label={language === 'fr' ? 'Carte des clusters de boîtiers' : 'Box cluster map'}>
                  <defs><linearGradient id="franceGrad" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" stopColor="#E9F2F4" /><stop offset="100%" stopColor="#DCE9ED" /></linearGradient></defs>
                  <path d="M 270 40 L 340 60 L 410 110 L 460 140 L 470 200 L 440 240 L 480 310 L 460 380 L 420 440 L 370 450 L 310 470 L 250 460 L 210 430 L 150 370 L 170 300 L 120 280 L 70 240 L 90 200 L 160 190 L 200 130 L 240 70 Z" fill="url(#franceGrad)" stroke="rgba(74,122,138,0.35)" strokeWidth="1.5" strokeDasharray="4 2" />
                  {displayZones.map((zone) => {
                    const { x, y } = projectCoords(zone.lat, zone.lng);
                    const selected = selectedZone?.id === zone.id;
                    const weight = metricByCoordinate.get(`${zone.lat}:${zone.lng}`) ?? (viewMode === 'boxes' ? zone.boxes : zone.kwh);
                    const radius = Math.min(44, Math.max(8, Math.sqrt(Math.max(weight, 1)) * (viewMode === 'boxes' ? 1.3 : 0.3)));
                    const color = viewMode === 'boxes' ? 'primary.main' : 'error.main';
                    return <g key={zone.id} onClick={() => setSelectedZoneId(zone.id)} role="button" tabIndex={0} aria-label={zone.name} onKeyDown={(event) => { if (event.key === 'Enter' || event.key === ' ') setSelectedZoneId(zone.id); }} style={{ cursor: 'pointer' }}>
                      {selected && <circle cx={x} cy={y} r={radius + 8} fill="none" stroke={color} strokeWidth="2" />}
                      <circle cx={x} cy={y} r={radius} fill={color} opacity={selected ? 0.35 : 0.18} />
                      <circle cx={x} cy={y} r="5" fill={color} />
                      <text x={x} y={y - radius - 9} textAnchor="middle" fill="#14262E" fontSize="10" fontWeight="700">{zone.city} ({viewMode === 'boxes' ? zone.boxes : `${Math.round(zone.kwh / 1000)}k`})</text>
                    </g>;
                  })}
                  {viewMode === 'energy' && heatPoints.map((point) => {
                    const { x, y } = projectCoords(point.lat, point.lng);
                    return <circle key={`${point.lat}:${point.lng}`} cx={x} cy={y} r={Math.min(18, Math.max(3, Math.sqrt(point.weight)))} fill="#E57373" opacity="0.4" />;
                  })}
                </svg>                  <Box sx={{ position: 'absolute', bottom: 16, left: 16, backgroundColor: 'rgba(255, 255, 255, 0.88)', border: '1px solid', borderColor: 'divider', p: 1.5 }}>
                  <Typography sx={{ fontSize: '0.72rem', fontWeight: 700, color: 'text.secondary', textTransform: 'uppercase' }}>{language === 'fr' ? 'Zones' : 'Zones'}</Typography>
                  <Typography sx={{ fontSize: '0.75rem', color: 'text.primary' }}>{language === 'fr' ? `${coverageQuery.data?.total_boxes ?? 0} boîtiers géolocalisés` : `${coverageQuery.data?.total_boxes ?? 0} geolocated boxes`}</Typography>
                  <Typography sx={{ fontSize: '0.75rem', color: 'text.primary' }}>{language === 'fr' ? `${coverageQuery.data?.unlocated_boxes ?? 0} sans position` : `${coverageQuery.data?.unlocated_boxes ?? 0} unlocated`}</Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>

          {selectedZone && <Card sx={{ backgroundColor: 'background.paper', border: '1px solid', borderColor: 'divider', p: 2.5 }}>
            <Typography sx={{ fontSize: '0.75rem', color: 'primary.main', fontWeight: 700, textTransform: 'uppercase' }}>{selectedZone.target > 0 ? `${Math.round((selectedZone.clients / selectedZone.target) * 100)}% objectif` : language === 'fr' ? 'Cluster' : 'Cluster'}</Typography>
            <Typography sx={{ fontSize: '1.25rem', fontWeight: 700, color: 'text.primary' }}>{selectedZone.name}</Typography>
            <Typography sx={{ fontSize: '0.82rem', color: 'text.secondary' }}>{selectedZone.lat.toFixed(4)}, {selectedZone.lng.toFixed(4)}</Typography>
            <Chip label={selectedZone.isActive ? (language === 'fr' ? 'Active' : 'Active') : (language === 'fr' ? 'Inactive' : 'Inactive')} size="small" sx={{ mt: 1, borderRadius: 0 }} />
            <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 1.5, my: 2 }}>
              <Metric label={language === 'fr' ? 'Clients' : 'Clients'} value={selectedZone.clients.toLocaleString()} />
              <Metric label={language === 'fr' ? 'Abonnés VIP' : 'VIP subscribers'} value={selectedZone.vip.toLocaleString()} />
              <Metric label={language === 'fr' ? 'Conso Énergie 30j' : '30d energy'} value={`${(selectedZone.kwh / 1000).toFixed(1)} MWh`} />
              <Metric label={language === 'fr' ? 'Objectif' : 'Target'} value={selectedZone.target.toLocaleString()} />
            </Box>
            <Typography sx={{ fontSize: '0.78rem', color: 'text.secondary' }}>{selectedZone.target > 0 ? (language === 'fr' ? 'Progression par rapport à l’objectif commercial de cette zone.' : 'Progress against this zone’s commercial target.') : (language === 'fr' ? 'Statistiques agrégées du cluster géographique.' : 'Aggregated geographic cluster statistics.')}</Typography>
          </Card>}
        </Box>
      )}
    </Box>
  );
};

function Metric({ label, value }: { label: string; value: string }) {
  return <Box sx={{ backgroundColor: 'action.hover', p: 1.8, border: '1px solid', borderColor: 'divider' }}><Typography sx={{ fontSize: '0.72rem', color: 'text.secondary' }}>{label}</Typography><Typography sx={{ fontSize: '1.3rem', fontWeight: 700, color: 'text.primary' }}>{value}</Typography></Box>;
}
