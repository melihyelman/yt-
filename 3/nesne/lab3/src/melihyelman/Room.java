package melihyelman;

import java.util.ArrayList;

public class Room {
	private static int nextRoomNumber = 1;
	private int roomNumber;
	private int durationOfStay;
	private ArrayList<Treatment> treatments;
	
	public Room(int durationOfStay) {
		this.durationOfStay = durationOfStay;
		treatments = new ArrayList<>();
		roomNumber = nextRoomNumber;
		nextRoomNumber = roomNumber++;
	}

	public int getRoomNumber() {
		return roomNumber;
	}
	
	public void addTreatment(Treatment treatment) {
		treatments.add(treatment);
	}

	@Override
	public String toString() {
		return "Room: " + roomNumber + ", Duration of Stay: " + durationOfStay ;
	}
	
}
