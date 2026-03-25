import {
  QueryClient,
  QueryClientProvider,
  useQuery
} from '@tanstack/react-query'

function SignalViewer(props: any) {
  return (
    <div className="signal-viewer">
      <span className="signal-viewer-signal-title">{props.signal}</span>
      <span className="signal-viewer-signal-value">{props.value}</span>
    </div>
  );
}

const queryClient = new QueryClient()

async function getList() {
  return await fetch('/api/list')
    .then((response) => response.json())
    .then((json) => json.list);
}

function List() {
  const list = useQuery({ queryKey: ['list'], queryFn: getList });

  return (
      <div>
        {list.data?.map((signal: string) => (<SignalViewer signal={signal} value="0" />))}
      </div>
  );
}

function App() {

  return (
    <QueryClientProvider client={queryClient}>
      <List />
    </QueryClientProvider>
  )
}

export default App
