export interface Event {
    id: string;
    title: string;
    description: string;
    date: string;
    time: string;
    location: string;
    lat: number;
    lng: number;
    image: string;
    organizer: {
        name: string;
        avatar: string;
    };
    attendees: number;
    category: string;
}

export interface User {
    id: string;
    name: string;
    email: string;
    avatar: string;
    color: string;
}

export interface MapMarker {
    id: string;
    lat: number;
    lng: number;
    type: 'event' | 'user';
    data: any;
}
